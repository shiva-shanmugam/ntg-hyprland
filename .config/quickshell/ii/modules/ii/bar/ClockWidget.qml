import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool vertical: false
    property bool showDate: Config.options.bar.verbose
    readonly property real verticalWidth: Appearance.sizes.baseVerticalBarWidth - 8
    implicitWidth: vertical ? Math.min(verticalWidth, clockLayout.implicitWidth) : clockLayout.implicitWidth
    implicitHeight: vertical ? clockLayout.implicitHeight : Appearance.sizes.barHeight

    GridLayout {
        id: clockLayout
        anchors.centerIn: parent
        columns: root.vertical ? 1 : -1
        columnSpacing: 4
        rowSpacing: 2

        ClockFace {
            Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            Layout.topMargin: root.vertical ? 0 : 4
            scale: root.vertical ? Math.min(1, root.verticalWidth / Math.max(1, implicitWidth)) : 1
            font.family: Appearance.font.family.numbers
            font.pixelSize: root.vertical ? 17 : 23
            color: Appearance.colors.colOnLayer0
            value: DateTime.time
        }

        StyledText {
            visible: root.showDate && !root.vertical
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
            text: "•"
        }

        StyledText {
            visible: root.showDate
            Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
            Layout.maximumWidth: root.vertical ? root.verticalWidth : Infinity
            font.family: Appearance.font.family.monospace
            font.pixelSize: root.vertical ? 10 : Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
            text: root.vertical ? DateTime.shortDate : DateTime.longDate
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow

        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            if (event.button === Qt.LeftButton) infoPopup.toggle();
        }

        ClockWidgetPopup {
            id: infoPopup
            hoverTarget: mouseArea
        }
    }
}
