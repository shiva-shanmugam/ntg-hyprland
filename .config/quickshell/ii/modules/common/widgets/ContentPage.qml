import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledFlickable {
    id: root
    property real bottomContentPadding: 28
    readonly property real gutter: Math.max(12, Math.min(24, width * 0.025))

    default property alias contentData: contentColumn.data

    clip: true
    contentWidth: width
    contentHeight: contentColumn.y + contentColumn.implicitHeight + bottomContentPadding
    
    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 6
            leftMargin: root.gutter
            rightMargin: root.gutter
        }
        spacing: 14
    }

}
