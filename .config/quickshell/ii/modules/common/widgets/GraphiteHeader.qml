import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common

ClippingRectangle {
    id: root
    required property string title
    property string detail
    implicitHeight: 76
    radius: Appearance.rounding.surfaceRadius(width, height)
    color: Appearance.colors.colLayer0

    Image {
        anchors.fill: parent
        anchors.leftMargin: root.width * 0.14
        source: Quickshell.shellPath("assets/images/graphite-panel.jpg")
        fillMode: Image.PreserveAspectCrop
        horizontalAlignment: Image.AlignRight
    }

    Rectangle {
        anchors.fill: parent
        visible: !DesktopPalette.dark
        property color tint: DesktopPalette.black
        id: artWash

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: artWash.tint }
            GradientStop { position: 0.69; color: artWash.tint }
            GradientStop {
                position: 1
                color: Qt.rgba(artWash.tint.r, artWash.tint.g, artWash.tint.b, 0.38)
            }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * 0.68
        spacing: 2

        StyledText {
            width: parent.width
            text: root.title
            font.family: Appearance.font.family.title
            font.pixelSize: 26
            font.weight: Font.DemiBold
            font.letterSpacing: -0.6
            elide: Text.ElideRight
            color: Appearance.colors.colOnLayer0
        }
        StyledText {
            width: parent.width
            visible: text.length > 0
            text: root.detail
            font.family: Appearance.font.family.monospace
            font.pixelSize: 11
            elide: Text.ElideRight
            color: DesktopPalette.dark ? "#c6c6c6" : DesktopPalette.muted
        }
    }
}
