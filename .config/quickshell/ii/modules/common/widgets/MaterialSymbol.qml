import qs.modules.common
import QtQuick

StyledText {
    id: root
    property real iconSize: Appearance?.font.pixelSize.small ?? 16
    property real fill: 0
    property real truncatedFill: fill.toFixed(1) // Reduce memory consumption spikes from constant font remapping
    renderType: Text.NativeRendering
    font {
        hintingPreference: Font.PreferNoHinting
        family: Appearance?.font.family.iconMaterial ?? "Material Symbols Rounded"
        pixelSize: iconSize
        weight: Font.Normal
        variableAxes: ({
            "FILL": truncatedFill * 0.75,
            "wght": 350,
            "GRAD": -20,
            "opsz": Math.max(20, Math.min(48, iconSize))
        })
    }

    Behavior on fill { // Leaky leaky, no good
        NumberAnimation {
            duration: Appearance?.animation.elementMoveFast.duration ?? 200
            easing.type: Appearance?.animation.elementMoveFast.type ?? Easing.BezierSpline
            easing.bezierCurve: Appearance?.animation.elementMoveFast.bezierCurve ?? [0.34, 0.80, 0.34, 1.00, 1, 1]
        }
    }
}
