import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar as Bar

Item {
    id: root
    readonly property bool showIslands: Config.options.bar.cornerStyle === 1 && Config.options.bar.showBackground
    readonly property real islandSpacing: showIslands ? 8 : 4
    readonly property real edgeMargin: showIslands ? Appearance.sizes.hyprlandGapsOut : 4

    Rectangle {
        anchors.fill: parent
        visible: Config.options.bar.showBackground && !root.showIslands
        color: Appearance.colors.colLayer0
    }

    Column {
        id: topGroup
        anchors {
            top: parent.top
            topMargin: root.edgeMargin
            horizontalCenter: parent.horizontalCenter
        }
        spacing: root.islandSpacing

        Bar.BarGroup {
            visible: Config.options.policies.ai !== 0 || Config.options.sidebar.translator.enable
            vertical: true
            island: root.showIslands
            padding: 4

            FocusedScrollMouseArea {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 34
                implicitHeight: 32
                onScrollDown: Brightness.decreaseBrightness()
                onScrollUp: Brightness.increaseBrightness()
                onMovedAway: GlobalStates.osdBrightnessOpen = false

                Bar.LeftSidebarButton {
                    anchors.centerIn: parent
                }
            }
        }

        Bar.BarGroup {
            visible: !!mediaWidget.activePlayer?.trackTitle
            vertical: true
            island: root.showIslands
            padding: 4

            Bar.Media {
                id: mediaWidget
                compact: true
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: false
            }
        }
    }

    Bar.BarGroup {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(topGroup.y + topGroup.height + root.islandSpacing,
            Math.min((root.height - height) / 2, bottomGroup.y - root.islandSpacing - height))
        vertical: true
        island: root.showIslands
        padding: 8

        Bar.Workspaces {
            Layout.alignment: Qt.AlignHCenter
            vertical: true
            workspaceButtonWidth: {
                const available = bottomGroup.y - (topGroup.y + topGroup.height) - 2 * root.islandSpacing - 16;
                return Math.max(12, Math.min(26, Math.floor(available / Math.max(1, workspacesShown))));
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onPressed: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
            }
        }
    }

    Column {
        id: bottomGroup
        anchors {
            bottom: parent.bottom
            bottomMargin: root.edgeMargin
            horizontalCenter: parent.horizontalCenter
        }
        spacing: root.islandSpacing

        Bar.BarGroup {
            vertical: true
            island: root.showIslands
            padding: 4

            Bar.ControlCentreButton { Layout.alignment: Qt.AlignHCenter }
        }

        Bar.BarGroup {
            vertical: true
            island: root.showIslands
            padding: 4

            Bar.UtilButtons {
                Layout.alignment: Qt.AlignHCenter
                vertical: true
            }

            Bar.ClockWidget {
                Layout.alignment: Qt.AlignHCenter
                vertical: true
                showDate: true
            }

            Bar.BatteryIndicator {
                visible: Battery.available
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 14
            }
        }
    }
}
