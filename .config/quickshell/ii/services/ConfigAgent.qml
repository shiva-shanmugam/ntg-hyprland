pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string stateDirectory: FileUtils.trimFileProtocol(Directories.state) + "/user/agent"
    readonly property string script: FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/ai/assistant-agent.py"))
    readonly property var chatModel: Ai.getModel()
    readonly property string model: chatModel?.api_format === "ollama" && chatModel.capabilities.includes("tools")
        ? chatModel.model : "qwen3:8b"
    readonly property string modelName: model === chatModel?.model ? chatModel.name : "Qwen3 (8B)"
    readonly property bool active: ["starting", "running", "stopping", "undoing"].includes(snapshot.status ?? "")
    readonly property bool canUndo: !active && Boolean(snapshot.undoId)
    readonly property bool handlingRequest: control.running

    property var snapshot: ({})
    property string controlError: ""

    function send(operation, value = {}) {
        if (control.running) return false;
        controlError = "";
        control.operation = operation;
        control.payload = JSON.stringify(value);
        control.stdinEnabled = operation === "start";
        control.command = ["python3", "-B", root.script, operation, root.stateDirectory];
        control.running = true;
        return true;
    }

    function start(task, project, edit, screen) {
        if (active || !task.trim()) return false;
        return send("start", { task: task.trim(), project, edit, screen, model });
    }

    function stop() {
        if (active) send("stop");
    }

    function undo() {
        if (canUndo) send("undo");
    }

    FileView {
        id: stateView
        path: root.stateDirectory + "/current.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.snapshot = JSON.parse(text()); }
            catch (error) { root.controlError = Translation.tr("Could not read the agent's job state."); }
        }
    }

    // Atomic state writes and reloads can replace the watched inode.
    Timer {
        interval: 400
        repeat: true
        running: root.active || root.handlingRequest
        onTriggered: stateView.reload()
    }

    Process {
        id: control
        property string operation
        property string payload
        stderr: StdioCollector { id: controlLog }

        onStarted: if (operation === "start") {
            write(payload);
            stdinEnabled = false;
            payload = "";
        }
        onExited: code => {
            if (code !== 0)
                root.controlError = controlLog.text.trim() || Translation.tr("Agent command failed.");
            stateView.reload();
        }
    }
}
