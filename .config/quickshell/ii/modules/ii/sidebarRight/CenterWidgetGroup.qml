import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.ii.sidebarRight.notifications
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: Appearance.rounding.surfaceRadius(width, height)
    color: Appearance.colors.colLayer0Base
    border.color: Appearance.colors.colOutlineVariant
    border.width: 1

    NotificationList {
        anchors.fill: parent
        anchors.margins: 5
    }
}
