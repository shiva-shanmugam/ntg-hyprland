pragma Singleton
import QtQuick

QtObject {
    readonly property int columns: 4
    readonly property int unit: 84
    readonly property int gap: 8
    readonly property int inset: 10
    readonly property int controlIconSize: 34
    readonly property int padding: 10
    readonly property int tight: 4
    readonly property int cardRadius: 17
    readonly property int squareRadius: 7
    readonly property int hairline: 1
    readonly property int glyphDot: 1
    readonly property real glyphGap: 0.65
    readonly property int heroDot: 3
    readonly property int heroGap: 2
    readonly property real digitDot: 1.3
    readonly property real digitGap: 0.8
    readonly property int meterDot: 3
    readonly property int meterGap: 3
    readonly property int slideDistance: 12
    readonly property int animationMs: 125
    readonly property int staggerMs: 8
    readonly property int exitMs: animationMs + 10
    readonly property int armMs: 3000
    readonly property int previewIconSize: 100

    function span(cells: int): int {
        return cells * unit + Math.max(0, cells - 1) * gap;
    }

    function radius(shape: string, width: real, height: real): real {
        const limit = Math.min(width, height) / 2;
        return shape === "circle" || shape === "pill" ? limit
            : Math.min(limit, shape === "square" ? squareRadius : cardRadius);
    }
}
