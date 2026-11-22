import qs.modules.common
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    property string glyph: "device"
    property real glyphSize: 19
    property color ink: DesktopPalette.text
    implicitWidth: Math.max(NothingMetrics.padding * 3, glyphSize + 12)
    implicitHeight: implicitWidth
    hoverEnabled: true
    opacity: enabled ? 1 : 0.38
    padding: 0

    background: Rectangle {
        color: root.down || root.hovered ? Qt.alpha(DesktopPalette.raised, 0.78) : "transparent"
        border.width: root.visualFocus ? NothingMetrics.hairline : 0
        border.color: root.ink
        radius: NothingMetrics.squareRadius
    }

    contentItem: Item {
        ControlGlyph {
            anchors.centerIn: parent
            glyph: root.glyph
            iconSize: root.glyphSize
            color: root.ink
        }
    }
}
