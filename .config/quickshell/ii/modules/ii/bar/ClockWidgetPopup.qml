pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.calendar
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    readonly property var upcoming: Todo.list.filter(task => !task.done)

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        StyledPopupHeaderRow {
            icon: "calendar_month"
            label: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM dd, yyyy")
        }

        CalendarWidget {
            Layout.alignment: Qt.AlignHCenter
        }

        StyledPopupValueRow {
            icon: "timelapse"
            label: Translation.tr("Uptime")
            value: DateTime.uptime
        }

        StyledText {
            visible: root.upcoming.length > 0
            Layout.fillWidth: true
            Layout.maximumWidth: 260
            maximumLineCount: 6
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: root.upcoming.slice(0, 5).map(task => "• " + task.content).join("\n")
            color: Appearance.colors.colSubtext
        }
    }
}
