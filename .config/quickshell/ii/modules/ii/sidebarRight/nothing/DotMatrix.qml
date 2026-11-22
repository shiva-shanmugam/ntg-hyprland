import qs.modules.common
pragma ComponentBehavior: Bound
import QtQuick

Canvas {
    id: root
    property list<string> bitmap: []
    property real dotSize: NothingMetrics.glyphDot
    property real dotGap: NothingMetrics.glyphGap
    property color onColor: DesktopPalette.text
    property color offColor: "transparent"
    property real level: 1
    property bool sweeping: false
    property real phase: 0
    readonly property int columns: bitmap.reduce((max, row) => Math.max(max, row.length), 0)
    readonly property real pitch: dotSize + dotGap

    implicitWidth: columns ? columns * pitch - dotGap : 0
    implicitHeight: bitmap.length ? bitmap.length * pitch - dotGap : 0

    onBitmapChanged: requestPaint()
    onDotSizeChanged: requestPaint()
    onDotGapChanged: requestPaint()
    onOnColorChanged: requestPaint()
    onOffColorChanged: requestPaint()
    onLevelChanged: requestPaint()
    onPhaseChanged: requestPaint()
    onSweepingChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    NumberAnimation on phase {
        running: root.sweeping && root.visible
        from: 0
        to: 1
        duration: 900
        loops: Animation.Infinite
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        const lit = Math.round(columns * Math.max(0, Math.min(1, level)));
        for (let y = 0; y < bitmap.length; ++y) {
            for (let x = 0; x < bitmap[y].length; ++x) {
                const on = bitmap[y][x] === "X" && x < lit;
                const fill = on ? onColor : offColor;
                if (fill.a === 0)
                    continue;
                ctx.fillStyle = fill;
                ctx.globalAlpha = on && sweeping ? 0.35 + 0.65 * (1 - Math.abs(Math.cos(Math.PI * (x / columns - phase)))) : 1;
                ctx.beginPath();
                ctx.arc(x * pitch + dotSize / 2, y * pitch + dotSize / 2, dotSize / 2, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
    }
}
