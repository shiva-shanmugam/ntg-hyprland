import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100

    implicitWidth: batteryProgress.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    Accessible.name: Translation.tr("Battery %1%").arg(Math.round(percentage * 100))

    Row {
        id: batteryProgress
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        spacing: 2
        Repeater {
            model: 6
            Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: 4
                radius: 2
                color: index < Math.ceil(root.percentage * 6)
                    ? (root.isLow && !root.isCharging ? Appearance.colors.colError : Appearance.colors.colOnLayer0)
                    : Appearance.colors.colOutlineVariant
            }
        }
        MaterialSymbol {
            visible: root.isCharging
            anchors.verticalCenter: parent.verticalCenter
            text: "bolt"
            iconSize: 12
        }
    }

    cursorShape: Qt.PointingHandCursor
    onClicked: event => {
        if (event.button === Qt.LeftButton) batteryPopup.toggle();
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}
