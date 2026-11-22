pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs
import qs.modules.common
import qs.services

QtObject {
    id: root

    property bool airplaneMode: false
    property bool restoreWifi: false
    property bool restoreBluetooth: false
    property bool externalRecording: false
    property bool profileAvailable: false
    readonly property bool recording: recorder.running || externalRecording
    readonly property bool observing: GlobalStates.sidebarRightOpen && Config.options.sidebar.nothingControlCentre

    function toggleAirplane() {
        const adapter = Bluetooth.defaultAdapter;
        if (airplaneMode) {
            if (restoreWifi) Network.enableWifi(true);
            if (adapter && restoreBluetooth) adapter.enabled = true;
            airplaneMode = false;
        } else {
            restoreWifi = Network.wifiEnabled;
            restoreBluetooth = adapter?.enabled ?? false;
            if (restoreWifi) Network.enableWifi(false);
            if (adapter && restoreBluetooth) adapter.enabled = false;
            airplaneMode = true;
        }
    }

    function record() {
        if (!recordDelay.running) {
            GlobalStates.sidebarRightOpen = false;
            recordDelay.start();
        }
    }

    property Timer recordDelay: Timer {
        interval: NothingMetrics.exitMs + NothingMetrics.staggerMs * 4
        onTriggered: {
            if (recorder.running)
                stopRecorder.running = true;
            else
                recorder.running = true;
        }
    }

    property Process recorder: Process {
        command: [Directories.recordScriptPath, "--fullscreen", "--sound"]
        onExited: root.externalRecording = false
    }

    property Process stopRecorder: Process {
        command: recorder.command
        onExited: recordingProbe.running = true
    }

    property Process recordingProbe: Process {
        command: ["pgrep", "-x", "wf-recorder"]
        onExited: exitCode => root.externalRecording = exitCode === 0 && !recorder.running
    }

    property Process readProfiles: Process {
        command: ["busctl", "--system", "--no-pager", "--no-legend", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.profileAvailable =
                /^(org\.freedesktop\.UPower\.PowerProfiles|net\.hadess\.PowerProfiles)\s/m.test(text)
        }
    }

    onObservingChanged: if (observing) {
        recordingProbe.running = true;
        readProfiles.running = true;
    }
}
