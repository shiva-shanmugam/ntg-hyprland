import QtQuick
import QtQuick.Effects

RectangularShadow {
    required property Rectangle target
    anchors.fill: target
    radius: target.radius
    blur: 10
    color: "#2C000000"
    cached: true
}
