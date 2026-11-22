import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.ii.sidebarRight.nothing

Scope {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    readonly property bool floatingTiles: Config.options.sidebar.nothingControlCentre
    readonly property bool opened: GlobalStates.sidebarRightOpen

    onOpenedChanged: {
        if (opened) {
            exitDelay.stop();
            GlobalFocusGrab.addDismissable(panelWindow);
            sidebarContentLoader.forceActiveFocus();
        } else {
            GlobalFocusGrab.removeDismissable(panelWindow);
            if (floatingTiles)
                exitDelay.restart();
        }
    }

    Timer {
        id: exitDelay
        interval: NothingMetrics.exitMs
    }

    PanelWindow {
        id: panelWindow
        visible: root.opened || (root.floatingTiles && exitDelay.running)

        function hide() {
            GlobalStates.sidebarRightOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: root.floatingTiles ? NothingMetrics.span(NothingMetrics.columns) + NothingMetrics.inset * 2 : sidebarWidth
        WlrLayershell.namespace: root.floatingTiles ? "quickshell:nothingControlCentre" : "quickshell:sidebarRight"
        WlrLayershell.layer: root.floatingTiles ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.sidebarRightOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"
        mask: root.floatingTiles ? (root.opened ? sidebarContentLoader.item?.inputRegion ?? emptyMask : emptyMask) : null

        Region { id: emptyMask }

        anchors {
            top: true
            right: true
            bottom: true
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                panelWindow.hide();
            }
        }

        Loader {
            id: sidebarContentLoader
            active: panelWindow.visible || Config.options.sidebar.keepRightSidebarLoaded
            anchors {
                fill: parent
                margins: root.floatingTiles ? NothingMetrics.inset : Appearance.sizes.hyprlandGapsOut
                leftMargin: root.floatingTiles ? NothingMetrics.inset : Appearance.sizes.elevationMargin
            }

            focus: GlobalStates.sidebarRightOpen
            Keys.onEscapePressed: {
                if (root.floatingTiles && sidebarContentLoader.item)
                    sidebarContentLoader.item.handleEscape();
                else
                    panelWindow.hide();
            }

            sourceComponent: root.floatingTiles ? floatingContent : legacyContent
        }
    }

    Component {
        id: floatingContent
        NothingControlCentre {
            opened: root.opened
            inputOrigin: Qt.point(sidebarContentLoader.x + x, sidebarContentLoader.y + y)
            onDismiss: panelWindow.hide()
        }
    }

    Component {
        id: legacyContent
        SidebarRightContent {}
    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }

        function close(): void {
            GlobalStates.sidebarRightOpen = false;
        }

        function open(): void {
            GlobalStates.sidebarRightOpen = true;
        }
    }

    GlobalShortcut {
        name: "sidebarRightToggle"
        description: "Toggles right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
    }
    GlobalShortcut {
        name: "sidebarRightOpen"
        description: "Opens right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = true;
        }
    }
    GlobalShortcut {
        name: "sidebarRightClose"
        description: "Closes right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = false;
        }
    }
}
