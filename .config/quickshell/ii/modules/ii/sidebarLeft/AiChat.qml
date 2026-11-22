import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarLeft.aiChat
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property real padding: 8
    property var inputField: messageInputField
    property string commandPrefix: "/"

    readonly property string voiceScript: Directories.voiceTranscribeScriptPath
    property string recordingPath: ""
    property bool finishRecording: false
    property bool discardRecording: false
    readonly property bool voiceTranscribing: voiceTranscribeProcess.running

    Process {
        id: voiceRecordProcess
        command: ["bash", root.voiceScript, "record"]
        stdout: SplitParser { onRead: path => root.recordingPath = path.trim() }
        stderr: StdioCollector { id: recordErrors }
        onExited: exitCode => {
            recordingLimit.stop();
            const path = root.recordingPath;
            root.recordingPath = "";
            if (root.finishRecording && path) {
                voiceTranscribeProcess.command = ["bash", root.voiceScript, "transcribe", path];
                voiceTranscribeProcess.running = true;
            } else {
                if (path) Quickshell.execDetached(["bash", root.voiceScript, "discard", path]);
                if (!root.discardRecording)
                    Ai.notice(Translation.tr("Recording failed: %1").arg(recordErrors.text.trim() || Translation.tr("no audio input")));
            }
            root.finishRecording = false;
            root.discardRecording = false;
        }
    }

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            if (!GlobalStates.sidebarLeftOpen && voiceRecordProcess.running) {
                root.discardRecording = true;
                voiceRecordProcess.running = false;
            }
        }
    }

    Timer {
        id: recordingLimit
        interval: 110000
        onTriggered: root.toggleVoiceRecording()
    }

    Process {
        id: voiceTranscribeProcess
        stdout: StdioCollector { id: transcript }
        stderr: StdioCollector { id: transcribeErrors }
        onExited: exitCode => {
            const result = transcript.text.trim();
            if (exitCode !== 0) {
                Ai.notice(Translation.tr("Dictation failed: %1").arg(transcribeErrors.text.trim()));
            } else if (result) {
                messageInputField.insert(messageInputField.cursorPosition,
                    (messageInputField.text.length ? " " : "") + result);
            } else {
                Ai.notice(Translation.tr("No speech detected."));
            }
        }
    }

    function toggleVoiceRecording() {
        if (voiceTranscribing) return;
        if (voiceRecordProcess.running) {
            finishRecording = true;
            voiceRecordProcess.running = false;
        } else {
            recordingPath = "";
            voiceRecordProcess.running = true;
            recordingLimit.restart();
        }
    }

    FileDialog {
        id: attachmentDialog
        title: Ai.supportsImages ? Translation.tr("Attach a text file or image") : Translation.tr("Attach a text file")
        nameFilters: Ai.supportsImages
            ? [Translation.tr("Text and images (*.txt *.md *.log *.csv *.json *.png *.jpeg *.jpg *.webp)"), Translation.tr("All files (*)")]
            : [Translation.tr("Text files (*.txt *.md *.log *.csv *.json)"), Translation.tr("All files (*)")]
        onAccepted: Ai.attachFile(selectedFile.toString())
    }

    property var suggestionQuery: ""
    property var suggestionList: []

    onFocusChanged: {
        if (focus) {
            root.inputField.forceActiveFocus();
        }
    }

    Keys.onPressed: event => {
        messageInputField.forceActiveFocus();
        if (event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageUp) {
                messageListView.scrollPage(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_PageDown) {
                messageListView.scrollPage(1);
                event.accepted = true;
            }
        }
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_O) {
            Ai.clearMessages();
        }
    }
    property var allCommands: [
        {
            name: "attach",
            description: Translation.tr("Attach a UTF-8 text file or an image on supported models."),
            execute: args => {
                const path = args.join(" ").trim();
                if (path) Ai.attachFile(path);
                else attachmentDialog.open();
            }
        },
        {
            name: "model",
            description: Translation.tr("Choose model"),
            execute: args => {
                Ai.setModel(args[0]);
            }
        },
        {
            name: "tool",
            description: Translation.tr("Set the tool to use for the model."),
            execute: args => {
                // console.log(args)
                if (args.length == 0 || args[0] == "get") {
                    Ai.addMessage(Translation.tr("Usage: %1tool TOOL_NAME").arg(root.commandPrefix), Ai.interfaceRole);
                } else {
                    const tool = args[0];
                    const switched = Ai.setTool(tool);
                    if (switched) {
                        Ai.addMessage(Translation.tr("Tool set to: %1").arg(tool), Ai.interfaceRole);
                    }
                }
            }
        },
        {
            name: "prompt",
            description: Translation.tr("Set the system prompt for the model."),
            execute: args => {
                if (args.length === 0 || args[0] === "get") {
                    Ai.printPrompt();
                    return;
                }
                Ai.loadPrompt(args.join(" ").trim());
            }
        },
        {
            name: "key",
            description: Translation.tr("Set API key"),
            execute: args => {
                if (args[0] == "get") {
                    Ai.printApiKey();
                } else {
                    Ai.setApiKey(args[0]);
                }
            }
        },
        {
            name: "save",
            description: Translation.tr("Save chat"),
            execute: args => {
                const joinedArgs = args.join(" ");
                if (joinedArgs.trim().length == 0) {
                    Ai.addMessage(Translation.tr("Usage: %1save CHAT_NAME").arg(root.commandPrefix), Ai.interfaceRole);
                    return;
                }
                Ai.saveChat(joinedArgs);
            }
        },
        {
            name: "load",
            description: Translation.tr("Load chat"),
            execute: args => {
                const joinedArgs = args.join(" ");
                if (joinedArgs.trim().length == 0) {
                    Ai.addMessage(Translation.tr("Usage: %1load CHAT_NAME").arg(root.commandPrefix), Ai.interfaceRole);
                    return;
                }
                Ai.loadChat(joinedArgs);
            }
        },
        {
            name: "clear",
            description: Translation.tr("Clear chat history"),
            execute: () => {
                Ai.clearMessages();
            }
        },
        {
            name: "models",
            description: Translation.tr("Refresh installed Ollama models"),
            execute: () => Ai.refreshModels()
        },
        {
            name: "history",
            description: Translation.tr("Check or change automatic history with /history on or /history off"),
            execute: args => Ai.setHistory(args[0])
        },
        {
            name: "temp",
            description: Translation.tr("Set temperature (randomness) of the model. Values range between 0 to 2 for Gemini, 0 to 1 for other models. Default is 0.5."),
            execute: args => {
                // console.log(args)
                if (args.length == 0 || args[0] == "get") {
                    Ai.printTemperature();
                } else {
                    const temp = Number(args[0]);
                    Ai.setTemperature(temp);
                }
            }
        },
        {
            name: "think",
            description: Translation.tr("Toggle thinking/reasoning mode. Usage: /think yes|no (no argument toggles)."),
            execute: args => {
                Ai.setThinking(args[0]);
            }
        },
        {
            name: "test",
            description: Translation.tr("Markdown test"),
            execute: () => {
                Ai.addMessage(`
<think>
This sample tests how the panel displays a longer reasoning block. Expand it and check that the text wraps at the panel edge, then collapse it to return to the answer.

A second paragraph checks spacing between blocks. The content below exercises tables, code, and mathematical notation.
</think>
## ✏️ Markdown test
### Formatting

- *Italic*, \`Monospace\`, **Bold**, [Link](https://example.com)
- Arch Linux icon <img src="${Quickshell.shellPath("assets/icons/arch-symbolic.svg")}" height="${Appearance.font.pixelSize.small}"/>

### Table

Quickshell vs AGS/Astal

|                          | Quickshell       | AGS/Astal         |
|--------------------------|------------------|-------------------|
| UI Toolkit               | Qt               | Gtk3/Gtk4         |
| Language                 | QML              | Js/Ts/Lua         |
| Reactivity               | Implied          | Needs declaration |
| Widget placement         | Mildly difficult | More intuitive    |
| Bluetooth & Wifi support | ❌               | ✅                |
| No-delay keybinds        | ✅               | ❌                |
| Development              | New APIs         | New syntax        |

### Code block

Just a hello world...

\`\`\`cpp
#include <bits/stdc++.h>
// This is intentionally very long to test scrolling
const std::string GREETING = \"Hello, world!\";
int main(int argc, char* argv[]) {
    std::cout << GREETING;
}
\`\`\`

### LaTeX


Inline w/ dollar signs: $\\frac{1}{2} = \\frac{2}{4}$

Inline w/ double dollar signs: $$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$$

Inline w/ backslash and square brackets \\[\\int_0^\\infty \\frac{1}{x^2} dx = \\infty\\]

Inline w/ backslash and round brackets \\(e^{i\\pi} + 1 = 0\\)
`, Ai.interfaceRole);
            }
        },
    ]

    function handleInput(inputText) {
        if (inputText.startsWith(commandPrefix)) {
            const [command, ...args] = inputText.slice(commandPrefix.length).trim().split(/\s+/);
            const entry = allCommands.find(item => item.name === command);
            if (entry) entry.execute(args);
            else Ai.notice(Translation.tr("Unknown command: %1").arg(command));
        } else if (!Ai.sendUserMessage(inputText)) {
            return false;
        }
        messageListView.jumpToLatest();
        return true;
    }

    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.padding

        StyledText {
            Layout.fillWidth: true
            visible: Boolean(Ai.statusError)
            text: Ai.statusError
            wrapMode: Text.WordWrap
            color: Appearance.colors.colError
        }

        Item {
            // Messages
            clip: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            ScrollEdgeFade {
                z: 1
                target: messageListView
                vertical: true
            }

            StyledListView { // Message list
                id: messageListView
                z: 0
                anchors.fill: parent
                spacing: 10
                popin: false

                touchpadScrollFactor: Config.options.interactions.scrolling.touchpadScrollFactor * 1.4
                mouseScrollFactor: Config.options.interactions.scrolling.mouseScrollFactor * 1.4

                // Growing delegates can clear atYEnd before the viewport has moved.
                property bool followingLatest: true
                property bool resumeWhenAtEnd: false
                readonly property bool scrollBarPressed: ScrollBar.vertical?.pressed ?? false

                function followLatest() {
                    if (followingLatest && !atYEnd && visible && height > 0 && count > 0)
                        positionViewAtEnd();
                }

                function jumpToLatest() {
                    resumeWhenAtEnd = false;
                    followingLatest = true;
                    Qt.callLater(followLatest);
                }

                function resumeAtEnd() {
                    if (resumeWhenAtEnd && atYEnd && !dragging && !scrollBarPressed)
                        jumpToLatest();
                }

                function pauseFollowing(resumeOnReturn) {
                    resumeWhenAtEnd = resumeOnReturn;
                    followingLatest = false;
                }

                function trackWheel(deltaY) {
                    if (deltaY > 0 && contentHeight > height) {
                        pauseFollowing(false);
                    } else if (deltaY < 0 && !followingLatest) {
                        resumeWhenAtEnd = true;
                        Qt.callLater(resumeAtEnd);
                    }
                }

                function scrollPage(direction) {
                    const first = originY - topMargin;
                    const last = Math.max(first, originY + contentHeight + bottomMargin - height);
                    const destination = Math.max(first, Math.min(last, contentY + direction * height / 2));
                    if (direction > 0 && destination >= last) {
                        jumpToLatest();
                    } else if (destination !== contentY) {
                        pauseFollowing(direction > 0);
                        contentY = destination;
                    }
                }

                onContentHeightChanged: Qt.callLater(followLatest)
                onHeightChanged: Qt.callLater(followLatest)
                onVisibleChanged: Qt.callLater(followLatest)
                onCountChanged: {
                    if (count === 0) jumpToLatest();
                    else Qt.callLater(followLatest);
                }
                onAcceleratedWheel: deltaY => trackWheel(deltaY)
                onAtYEndChanged: resumeAtEnd()
                onMovementEnded: resumeAtEnd()
                onDragStarted: if (contentHeight > height) pauseFollowing(true)
                onScrollBarPressedChanged: {
                    if (scrollBarPressed) pauseFollowing(true);
                    else resumeAtEnd();
                }

                WheelHandler {
                    enabled: !Config.options.interactions.scrolling.fasterTouchpadScroll
                    target: null
                    blocking: false
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        messageListView.trackWheel(event.pixelDelta.y || event.angleDelta.y);
                        event.accepted = false;
                    }
                }

                add: null // Prevent function calls from being janky

                model: ScriptModel {
                    values: Ai.messageIDs.filter(id => {
                        const message = Ai.messageByID[id];
                        return message?.visibleToUser ?? true;
                    })
                }
                delegate: AiMessage {
                    required property var modelData
                    required property int index
                    messageIndex: Ai.messageIDs.indexOf(modelData)
                    messageData: {
                        Ai.messageByID[modelData];
                    }
                    messageInputField: root.inputField
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: messageListView.count === 0 && parent.height > 220
                spacing: 12

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "forum"
                    iconSize: 36
                    color: DesktopPalette.muted
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Start a conversation")
                    font.family: Appearance.font.family.title
                    font.pixelSize: 22
                    color: Appearance.colors.colOnLayer0
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Repeater {
                        model: [
                            { label: Translation.tr("Choose model"), command: "model " },
                            { label: Translation.tr("Commands"), command: "" }
                        ]
                        RippleButton {
                            id: promptAction
                            required property var modelData
                            implicitWidth: actionLabel.implicitWidth + 24
                            implicitHeight: 32
                            buttonRadius: 16
                            Accessible.name: modelData.label
                            colBackground: Appearance.colors.colLayer2
                            onClicked: {
                                messageInputField.text = root.commandPrefix + modelData.command;
                                messageInputField.forceActiveFocus();
                                messageInputField.cursorPosition = messageInputField.length;
                            }
                            contentItem: StyledText {
                                id: actionLabel
                                text: promptAction.modelData.label
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Ctrl+O expand  ·  Ctrl+P pin  ·  Ctrl+D detach")
                    font.pixelSize: 10
                    color: Appearance.colors.colSubtext
                }
            }

            ScrollToBottomButton {
                z: 3
                target: messageListView
                visible: !messageListView.followingLatest && opacity > 0
                downAction: () => messageListView.jumpToLatest()
            }
        }

        DescriptionBox {
            text: root.suggestionList[suggestions.selectedIndex]?.description ?? ""
            showArrows: root.suggestionList.length > 1
        }

        FlowButtonGroup { // Suggestions
            id: suggestions
            visible: root.suggestionList.length > 0 && messageInputField.text.length > 0
            property int selectedIndex: 0
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                id: suggestionRepeater
                model: {
                    suggestions.selectedIndex = 0;
                    return root.suggestionList.slice(0, 10);
                }
                delegate: ApiCommandButton {
                    id: commandButton
                    colBackground: suggestions.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer
                    bounce: false
                    contentItem: StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.displayName ?? modelData.name
                    }

                    onHoveredChanged: {
                        if (commandButton.hovered) {
                            suggestions.selectedIndex = index;
                        }
                    }
                    onClicked: {
                        suggestions.acceptSuggestion(modelData.name);
                    }
                }
            }

            function acceptSuggestion(word) {
                const words = messageInputField.text.trim().split(/\s+/);
                if (words.length > 0) {
                    words[words.length - 1] = word;
                } else {
                    words.push(word);
                }
                const updatedText = words.join(" ") + " ";
                messageInputField.text = updatedText;
                messageInputField.cursorPosition = messageInputField.text.length;
                messageInputField.forceActiveFocus();
            }

            function acceptSelectedWord() {
                if (suggestions.selectedIndex >= 0 && suggestions.selectedIndex < suggestionRepeater.count) {
                    const word = root.suggestionList[suggestions.selectedIndex].name;
                    suggestions.acceptSuggestion(word);
                }
            }
        }

        Rectangle { // Input area
            id: inputWrapper
            property real spacing: 5
            Layout.fillWidth: true
            radius: Appearance.rounding.surfaceRadius(width, height)
            border.width: 1
            border.color: messageInputField.activeFocus ? DesktopPalette.outline : DesktopPalette.line
            color: DesktopPalette.surface
            implicitHeight: Math.max(inputFieldRowLayout.implicitHeight + inputFieldRowLayout.anchors.topMargin + commandButtonsRow.implicitHeight + commandButtonsRow.anchors.bottomMargin + spacing, 45) + (attachedFileIndicator.implicitHeight + spacing + attachedFileIndicator.anchors.topMargin)
            clip: true

            Behavior on implicitHeight {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }

            AttachedFileIndicator {
                id: attachedFileIndicator
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: visible ? 5 : 0
                }
                filePath: Ai.pendingFilePath
                onRemove: Ai.attachFile("")
            }

            RowLayout { // Input field and send button
                id: inputFieldRowLayout
                anchors {
                    bottom: commandButtonsRow.top
                    left: parent.left
                    right: parent.right
                    bottomMargin: 5
                }
                spacing: 0

                ScrollView {
                    id: inputScrollView
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(root.height * 3/5, messageInputField.height)
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    StyledTextArea { // The actual TextArea (inside ScrollView to enable scrolling)
                        id: messageInputField
                        anchors.fill: parent
                        wrapMode: TextArea.Wrap
                        padding: 10
                        color: DesktopPalette.text
                        placeholderTextColor: DesktopPalette.muted
                        placeholderText: Translation.tr("Message…  / for commands")

                        background: null

                        onTextChanged: {
                            // Handle suggestions
                            if (messageInputField.text.length === 0) {
                                root.suggestionQuery = "";
                                root.suggestionList = [];
                                return;
                            } else if (messageInputField.text.startsWith(`${root.commandPrefix}model`)) {
                                root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                const modelResults = Fuzzy.go(root.suggestionQuery, Ai.modelList.map(model => {
                                    return {
                                        name: Fuzzy.prepare(model),
                                        obj: model
                                    };
                                }), {
                                    all: true,
                                    key: "name"
                                });
                                root.suggestionList = modelResults.map(model => {
                                    return {
                                        name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "model ") : ""}${model.target}`,
                                        displayName: `${Ai.models[model.target].name}`,
                                        description: `${Ai.models[model.target].description}`
                                    };
                                });
                            } else if (messageInputField.text.startsWith(`${root.commandPrefix}prompt`)) {
                                root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                const promptFileResults = Fuzzy.go(root.suggestionQuery, Ai.promptFiles.map(file => {
                                    return {
                                        name: Fuzzy.prepare(file),
                                        obj: file
                                    };
                                }), {
                                    all: true,
                                    key: "name"
                                });
                                root.suggestionList = promptFileResults.map(file => {
                                    return {
                                        name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "prompt ") : ""}${file.target}`,
                                        displayName: `${FileUtils.trimFileExt(FileUtils.fileNameForPath(file.target))}`,
                                        description: Translation.tr("Load prompt from %1").arg(file.target)
                                    };
                                });
                            } else if (messageInputField.text.startsWith(`${root.commandPrefix}save`)) {
                                root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                const promptFileResults = Fuzzy.go(root.suggestionQuery, Ai.savedChats.map(file => {
                                    return {
                                        name: Fuzzy.prepare(file),
                                        obj: file
                                    };
                                }), {
                                    all: true,
                                    key: "name"
                                });
                                root.suggestionList = promptFileResults.map(file => {
                                    const chatName = file.target;
                                    return {
                                        name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "save ") : ""}${chatName}`,
                                        displayName: `${chatName}`,
                                        description: Translation.tr("Save chat to %1").arg(chatName)
                                    };
                                });
                            } else if (messageInputField.text.startsWith(`${root.commandPrefix}load`)) {
                                root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                const promptFileResults = Fuzzy.go(root.suggestionQuery, Ai.savedChats.map(file => {
                                    return {
                                        name: Fuzzy.prepare(file),
                                        obj: file
                                    };
                                }), {
                                    all: true,
                                    key: "name"
                                });
                                root.suggestionList = promptFileResults.map(file => {
                                    const chatName = file.target;
                                    return {
                                        name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "load ") : ""}${chatName}`,
                                        displayName: `${chatName}`,
                                        description: Translation.tr(`Load chat from %1`).arg(file.target)
                                    };
                                });
                            } else if (messageInputField.text.startsWith(`${root.commandPrefix}tool`)) {
                                root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                const toolResults = Fuzzy.go(root.suggestionQuery, Ai.availableTools.map(tool => {
                                    return {
                                        name: Fuzzy.prepare(tool),
                                        obj: tool
                                    };
                                }), {
                                    all: true,
                                    key: "name"
                                });
                                root.suggestionList = toolResults.map(tool => {
                                    const toolName = tool.target;
                                    return {
                                        name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "tool ") : ""}${tool.target}`,
                                        displayName: toolName,
                                        description: Ai.toolDescriptions[toolName]
                                    };
                                });
                            } else if (messageInputField.text.startsWith(root.commandPrefix)) {
                                root.suggestionQuery = messageInputField.text;
                                root.suggestionList = root.allCommands.filter(cmd => cmd.name.startsWith(messageInputField.text.substring(1))).map(cmd => {
                                    return {
                                        name: `${root.commandPrefix}${cmd.name}`,
                                        description: `${cmd.description}`
                                    };
                                });
                            }
                        }

                        function accept() {
                            root.handleInput(text);
                            text = "";
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Tab) {
                                suggestions.acceptSelectedWord();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up && suggestions.visible) {
                                suggestions.selectedIndex = Math.max(0, suggestions.selectedIndex - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down && suggestions.visible) {
                                suggestions.selectedIndex = Math.min(root.suggestionList.length - 1, suggestions.selectedIndex + 1);
                                event.accepted = true;
                            } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    // Insert newline
                                    messageInputField.insert(messageInputField.cursorPosition, "\n");
                                    event.accepted = true;
                                } else {
                                    if (root.handleInput(messageInputField.text)) messageInputField.clear();
                                    event.accepted = true;
                                }
                            } else if (event.key === Qt.Key_Escape) {
                                // Esc to detach file
                                if (Ai.pendingFilePath.length > 0) {
                                    Ai.attachFile("");
                                    event.accepted = true;
                                } else {
                                    event.accepted = false;
                                }
                            }
                        }
                    }
                }

                Button {
                    Layout.alignment: Qt.AlignBottom
                    implicitWidth: 34
                    implicitHeight: 38
                    enabled: !Ai.busy && !Ai.awaitingApproval
                    Accessible.name: Translation.tr("Attach a file")
                    onClicked: attachmentDialog.open()
                    background: Item {}
                    contentItem: MaterialSymbol {
                        text: "attach_file"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: parent.enabled ? DesktopPalette.text : DesktopPalette.muted
                    }
                }

                Button {
                    Layout.alignment: Qt.AlignBottom
                    implicitWidth: 34
                    implicitHeight: 38
                    enabled: !root.voiceTranscribing
                    Accessible.name: voiceRecordProcess.running ? Translation.tr("Stop recording") : Translation.tr("English dictation")
                    onClicked: root.toggleVoiceRecording()
                    background: Item {}
                    contentItem: MaterialSymbol {
                        text: root.voiceTranscribing ? "sync" : (voiceRecordProcess.running ? "stop" : "mic")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: voiceRecordProcess.running ? DesktopPalette.red : DesktopPalette.text
                    }
                }

                Button {
                    id: sendButton
                    Layout.alignment: Qt.AlignBottom
                    Layout.rightMargin: 5
                    implicitWidth: 40
                    implicitHeight: 38
                    enabled: Ai.busy || (!Ai.awaitingApproval && (messageInputField.text.trim().length > 0 || Ai.pendingFilePath.length > 0))
                    Accessible.name: Ai.busy ? Translation.tr("Stop reply") : Translation.tr("Send message")
                    onClicked: {
                        if (Ai.busy) Ai.stop();
                        else if (root.handleInput(messageInputField.text)) messageInputField.clear();
                    }
                    background: Rectangle {
                        radius: Appearance.rounding.windowRounding
                        color: sendButton.enabled ? DesktopPalette.red : DesktopPalette.raised
                    }
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        iconSize: 21
                        color: sendButton.enabled ? DesktopPalette.onAccent : DesktopPalette.muted
                        text: Ai.busy ? "stop" : "arrow_upward"
                    }
                }
            }

            RowLayout { // Controls
                id: commandButtonsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                anchors.leftMargin: 10
                anchors.rightMargin: 5
                spacing: 4

                property var commandsShown: [
                    {
                        name: "",
                        sendDirectly: false,
                        dontAddSpace: true
                    },
                    {
                        name: "clear",
                        sendDirectly: true
                    },
                    ...(Ai.supportsThinking ? [{ name: "think", sendDirectly: true }] : [])
                ]

                ApiInputBoxIndicator {
                    // Tool indicator
                    icon: "service_toolbox"
                    text: Ai.currentTool === "functions" ? Translation.tr("Desktop actions") : Ai.currentTool === "search" ? Translation.tr("Web search") : Translation.tr("Chat only")
                    tooltipText: Ai.toolDescriptions[Ai.currentTool]
                }

                Item {
                    Layout.fillWidth: true
                }

                ButtonGroup {
                    // Command buttons
                    padding: 0

                    Repeater {
                        // Command buttons
                        model: commandButtonsRow.commandsShown
                        delegate: ApiCommandButton {
                            property string commandRepresentation: `${root.commandPrefix}${modelData.name}`
                            buttonText: commandRepresentation
                            downAction: () => {
                                if (modelData.sendDirectly) {
                                    root.handleInput(commandRepresentation);
                                } else {
                                    messageInputField.text = commandRepresentation + (modelData.dontAddSpace ? "" : " ");
                                    messageInputField.cursorPosition = messageInputField.text.length;
                                    messageInputField.forceActiveFocus();
                                }
                                if (modelData.name === "clear") {
                                    messageInputField.text = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
