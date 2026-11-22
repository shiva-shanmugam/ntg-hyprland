pragma ComponentBehavior: Bound
import QtQuick

Row {
    id: face

    required property string value
    property font font
    property color color
    property bool animateChange: false
    property int renderStyle: Text.Normal
    property color styleColor: "transparent"
    readonly property var segments: value.split(/(:)/)
    readonly property real dot: Math.max(2, Math.round(font.pixelSize * 0.1))

    Accessible.role: Accessible.StaticText
    Accessible.name: value
    spacing: Math.max(2, Math.round(font.pixelSize * 0.14))

    FontMetrics { id: metrics; font: face.font }

    Repeater {
        model: face.segments.length
        delegate: Item {
            id: segment
            required property int index
            readonly property string value: face.segments[index] ?? ""
            readonly property bool isColon: value === ":"
            readonly property rect ink: metrics.tightBoundingRect(value)

            width: isColon ? face.dot : Math.max(0, ink.width)
            height: Math.ceil(metrics.height)

            Item {
                visible: !segment.isColon
                x: -segment.ink.x
                y: (segment.height - segment.ink.height) / 2 - metrics.ascent - segment.ink.y

                StyledText {
                    Accessible.ignored: true
                    text: segment.value
                    font: face.font
                    color: face.color
                    animateChange: face.animateChange
                    style: face.renderStyle
                    styleColor: face.styleColor
                    textFormat: Text.PlainText
                }
            }

            Column {
                anchors.centerIn: parent
                visible: segment.isColon
                spacing: Math.max(2, Math.round(face.font.pixelSize * 0.13))

                Repeater {
                    model: 2
                    Rectangle {
                        width: face.dot
                        height: face.dot
                        radius: face.dot * 0.23
                        color: face.color
                    }
                }
            }
        }
    }
}
