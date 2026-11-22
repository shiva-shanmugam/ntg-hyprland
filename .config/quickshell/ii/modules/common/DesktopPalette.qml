pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var current: ({})
    readonly property color black: current.black ?? "#000000"
    readonly property color panel: current.panel ?? "#0D0D0D"
    readonly property color surface: current.surface ?? "#141414"
    readonly property color raised: current.raised ?? "#1A1A1A"
    readonly property color line: current.line ?? "#2A2A2A"
    readonly property color outline: current.outline ?? "#444444"
    readonly property color muted: current.muted ?? "#8A8A8A"
    readonly property color text: current.text ?? "#FFFFFF"
    readonly property color red: current.red ?? "#D71921"
    readonly property color onAccent: "#FFFFFF"
    readonly property bool dark: current.dark ?? true
    readonly property int cornerRadius: current.cornerRadius ?? 8

    FileView {
        path: Directories.config + "/nothing-theme/active.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.current = JSON.parse(text());
            } catch (error) {
                console.warn("Could not read the active NTG palette:", error.message);
            }
        }
    }
}
