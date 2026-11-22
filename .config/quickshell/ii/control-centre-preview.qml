//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.nothing
import "modules/ii/sidebarRight/nothing/DotArt.js" as DotArt

ShellRoot {
    Window {
        id: preview
        title: "control centre dot art"
        visible: true
        color: DesktopPalette.black
        width: artGrid.implicitWidth + 24
        height: artGrid.implicitHeight + sample.height + 36

        ColumnLayout {
            anchors.centerIn: parent
            spacing: NothingMetrics.gap

            DotText {
                id: sample
                Layout.alignment: Qt.AlignHCenter
                text: "08:42  97%"
            }

            GridLayout {
                id: artGrid
                columns: 7
                rowSpacing: NothingMetrics.gap
                columnSpacing: NothingMetrics.gap

                Repeater {
                    model: Object.keys(DotArt.glyphs)
                    delegate: NothingTile {
                        id: iconTile
                        required property string modelData
                        width: NothingMetrics.previewIconSize
                        height: NothingMetrics.unit
                        Layout.preferredWidth: width
                        Layout.preferredHeight: height
                        shape: "card"
                        panelOpen: true
                        interactive: false

                        Column {
                            anchors.centerIn: parent
                            spacing: NothingMetrics.tight
                            DotMatrix {
                                anchors.horizontalCenter: parent.horizontalCenter
                                bitmap: DotArt.glyphs[iconTile.modelData]
                                dotSize: 2
                                dotGap: 1
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: iconTile.modelData
                                color: DesktopPalette.muted
                                font.family: Appearance.font.family.monospace
                            }
                        }
                    }
                }
            }
        }
    }
}
