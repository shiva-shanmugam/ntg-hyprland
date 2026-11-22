import QtQuick
import "DotArt.js" as DotArt

DotMatrix {
    id: root
    property string text: ""
    bitmap: DotArt.textBitmap(root.text)
    dotSize: NothingMetrics.digitDot
    dotGap: NothingMetrics.digitGap
}
