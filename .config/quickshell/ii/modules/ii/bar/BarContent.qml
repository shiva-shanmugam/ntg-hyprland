import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0
    readonly property bool showIslands: Config.options.bar.cornerStyle === 1 && Config.options.bar.showBackground
    readonly property real islandSpacing: showIslands ? 8 : 4
    readonly property real edgeMargin: showIslands ? Appearance.sizes.hyprlandGapsOut : 4

    Rectangle {
        anchors.fill: parent
        visible: Config.options.bar.showBackground && !root.showIslands
        color: Appearance.colors.colLayer0
    }

    FocusedScrollMouseArea { // Left side | scroll to change brightness
        id: barLeftSideMouseArea

        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: root.edgeMargin
        }
        readonly property real nextIslandX: mediaGroup.visible ? mediaGroup.x : middleCenterGroup.x
        width: Math.max(0, Math.min(contentWidth, nextIslandX - root.edgeMargin - root.islandSpacing))
        height: Appearance.sizes.baseBarHeight
        property real contentWidth: Math.min(300, leftSectionRowLayout.implicitWidth)

        Behavior on contentWidth {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        PanelSurface {
            anchors.fill: parent
            visible: root.showIslands && barLeftSideMouseArea.width > 0
        }

        onScrollDown: Brightness.decreaseBrightness()
        onScrollUp: Brightness.increaseBrightness()
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }

        // Visual content
        ScrollHint {
            reveal: barLeftSideMouseArea.hovered
            icon: Hyprsunset.gamma === 100 ? "light_mode" : "wb_twilight"
            side: "left"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        RowLayout {
            id: leftSectionRowLayout
            anchors.fill: parent
            spacing: 0
            clip: true

            LeftSidebarButton { // Left sidebar button
                id: leftSidebarButton
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                colBackground: barLeftSideMouseArea.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
            }

            ActiveWindow {
                Layout.leftMargin: leftSidebarButton.visible ? 0 : 12
                Layout.rightMargin: 14
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.useShortenedForm === 0
            }
        }
    }

    BarGroup {
        id: mediaGroup
        visible: root.useShortenedForm < 2 && !!mediaWidget.activePlayer?.trackTitle
        anchors {
            verticalCenter: parent.verticalCenter
            right: middleCenterGroup.left
            rightMargin: root.islandSpacing
        }
        island: root.showIslands
        padding: 4
        width: Math.min(implicitWidth, Math.max(0, middleCenterGroup.x - root.islandSpacing - root.edgeMargin))

        Behavior on implicitWidth {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Media {
            id: mediaWidget
            Layout.fillWidth: true
            Layout.maximumWidth: 220
        }

    }

    BarGroup {
        id: middleCenterGroup
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min((root.width - width) / 2, rightBar.x - root.islandSpacing - width))
        island: root.showIslands
        padding: workspacesWidget.widgetPadding + (root.showIslands ? 5 : 0)

        Workspaces {
            id: workspacesWidget
            Layout.fillHeight: true
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton

                onPressed: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
            }
        }
    }

    Row {
        id: rightBar
        anchors {
            right: parent.right
            rightMargin: root.edgeMargin
            verticalCenter: parent.verticalCenter
        }
        spacing: root.islandSpacing

        BarGroup {
            island: root.showIslands
            padding: 4

            ControlCentreButton {}
        }

        BarGroup {
            island: root.showIslands
            padding: 12

            UtilButtons {}

            ClockWidget {
                showDate: true
                Layout.preferredHeight: Appearance.sizes.baseBarHeight
                Layout.alignment: Qt.AlignVCenter
            }

            BatteryIndicator {
                visible: Battery.available
                Layout.leftMargin: 8
                Layout.preferredHeight: Appearance.sizes.baseBarHeight
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
