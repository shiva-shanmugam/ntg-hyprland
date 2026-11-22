import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.nothing
import QtQuick

Item {
    id: dayCell
    property string day
    property int isToday
    property bool bold
    implicitWidth: 38
    implicitHeight: 38

    Rectangle {
        anchors.fill: parent
        visible: dayCell.isToday === 1
        radius: Appearance.rounding.windowRounding
        color: DesktopPalette.text
    }

    DotText {
        anchors.centerIn: parent
        visible: !dayCell.bold
        text: dayCell.day
        onColor: dayCell.isToday === 1 ? DesktopPalette.black : dayCell.isToday === 0 ? DesktopPalette.text : DesktopPalette.muted
    }

    StyledText {
        anchors.centerIn: parent
        visible: dayCell.bold
        text: dayCell.day
        font.family: Appearance.font.family.monospace
        font.pixelSize: 11
        color: DesktopPalette.muted
    }
}
