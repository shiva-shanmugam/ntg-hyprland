import qs.modules.common
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Slider {
    id: root
    property bool alert: false
    property int dots: 16
    readonly property color lit: alert ? DesktopPalette.red : DesktopPalette.text
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0
    from: 0
    to: 1
    stepSize: 0.02
    implicitHeight: 17
    wheelEnabled: true

    background: DotMatrix {
        x: root.leftPadding
        y: (root.height - height) / 2
        width: implicitWidth
        height: implicitHeight
        bitmap: ["X".repeat(root.dots)]
        dotSize: NothingMetrics.meterDot
        dotGap: root.dots < 2 ? 0 : Math.max(0, (root.availableWidth - root.dots * dotSize) / (root.dots - 1))
        onColor: root.lit
        offColor: root.visualFocus ? DesktopPalette.outline : DesktopPalette.line
        level: root.visualPosition
    }

    handle: Item {}
}
