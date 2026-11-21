import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root
    signal remove()
    property bool canRemove: true
    property string filePath: ""
    readonly property bool isImage: /\.(png|jpe?g|webp)$/i.test(filePath)

    visible: Boolean(filePath)
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2
    implicitHeight: visible ? content.implicitHeight + 12 : 0

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            MaterialSymbol {
                text: root.isImage ? "image" : "description"
                iconSize: 18
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                text: FileUtils.fileNameForPath(root.filePath)
                color: Appearance.colors.colOnLayer1
            }
            Button {
                visible: root.canRemove
                implicitWidth: 28
                implicitHeight: 28
                Accessible.name: Translation.tr("Remove attachment")
                onClicked: root.remove()
                background: Item {}
                contentItem: MaterialSymbol {
                    text: "close"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        Loader {
            active: root.isImage && !root.canRemove
            visible: active
            Layout.fillWidth: true
            Layout.preferredHeight: active ? 108 : 0
            sourceComponent: Image {
                source: "file://" + encodeURI(root.filePath).replace(/#/g, "%23").replace(/\?/g, "%3F")
                sourceSize.width: 320
                sourceSize.height: 108
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }
    }
}
