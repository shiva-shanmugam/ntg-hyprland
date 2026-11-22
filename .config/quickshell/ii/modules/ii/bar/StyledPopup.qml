import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs
import qs.services
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root

    property Item hoverTarget
    property Item anchorTarget: hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    readonly property bool pinned: GlobalStates.barPopup === root

    active: pinned || (!Config.options.bar.tooltips.clickToShow && (hoverTarget?.containsMouse ?? false))

    function toggle() {
        GlobalStates.barPopup = pinned ? null : root;
    }

    Component.onDestruction: if (pinned) GlobalStates.barPopup = null

    component: PanelWindow {
        id: popupWindow
        screen: root.anchorTarget?.QsWindow?.window?.screen ?? null
        color: "transparent"
        readonly property bool captured: root.pinned && visible

        function updateCapture() {
            if (captured) {
                GlobalFocusGrab.addDismissable(popupWindow);
                popupBackground.forceActiveFocus();
            } else {
                GlobalFocusGrab.removeDismissable(popupWindow);
            }
        }

        onCapturedChanged: updateCapture()
        Component.onCompleted: updateCapture()
        Component.onDestruction: GlobalFocusGrab.removeDismissable(popupWindow)

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                if (root.pinned)
                    GlobalStates.barPopup = null;
            }
        }

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        mask: Region {
            item: popupBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: {
                if (Config.options.bar.vertical)
                    return Appearance.sizes.verticalBarWidth;

                const center = root.QsWindow?.mapFromItem(root.anchorTarget, root.anchorTarget.width / 2, 0)?.x ?? 0;
                const maxLeft = Math.max(0, (popupWindow.screen?.width ?? implicitWidth) - implicitWidth);
                return Math.max(0, Math.min(center - implicitWidth / 2, maxLeft));
            }
            top: {
                if (!Config.options.bar.vertical) return Appearance.sizes.barHeight;
                const center = root.QsWindow?.mapFromItem(root.anchorTarget, 0, root.anchorTarget.height / 2)?.y ?? 0;
                const maxTop = Math.max(0, (popupWindow.screen?.height ?? implicitHeight) - implicitHeight);
                return Math.max(0, Math.min(center - implicitHeight / 2, maxTop));
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 10
            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }
            implicitWidth: root.contentItem.implicitWidth + margin * 2
            implicitHeight: root.contentItem.implicitHeight + margin * 2
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.surfaceRadius(width, height)
            children: [root.contentItem]
            Keys.onEscapePressed: if (root.pinned) GlobalStates.barPopup = null

            border.width: 1
            border.color: Appearance.colors.colLayer0Border
        }
    }
}
