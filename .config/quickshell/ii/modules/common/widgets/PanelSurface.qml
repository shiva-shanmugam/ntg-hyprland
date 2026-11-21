import QtQuick
import qs.modules.common

Rectangle {
    property color tint: Appearance.colors.colLayer0Base

    color: tint
    radius: Appearance.rounding.surfaceRadius(width, height)
    border.width: 1
    border.color: Appearance.colors.colLayer0Border
}
