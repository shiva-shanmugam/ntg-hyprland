import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

PanelSurface {
    id: root
    property string title
    property string icon: ""
    default property alias contentData: sectionContent.data
    readonly property int padding: 14

    Layout.fillWidth: true
    implicitWidth: cardLayout.implicitWidth + padding * 2
    implicitHeight: cardLayout.implicitHeight + padding * 2

    ColumnLayout {
        id: cardLayout
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 9
            MaterialSymbol {
                visible: root.icon.length > 0
                text: root.icon
                fill: 0
                iconSize: 20
                color: DesktopPalette.red
            }
            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.family: Appearance.font.family.monospace
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                color: DesktopPalette.text
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: DesktopPalette.line
        }

        ColumnLayout {
            id: sectionContent
            Layout.fillWidth: true
            spacing: 6
        }
    }
}
