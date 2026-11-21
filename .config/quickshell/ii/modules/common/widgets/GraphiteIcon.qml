import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

IconImage {
    property bool monochrome: true

    layer.enabled: monochrome
    layer.effect: MultiEffect {
        saturation: -1
    }
}
