import QtQuick
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

FocusedScrollMouseArea {
    implicitWidth: 34
    implicitHeight: 32
    onScrollDown: Audio.decrementVolume()
    onScrollUp: Audio.incrementVolume()
    onMovedAway: GlobalStates.osdVolumeOpen = false

    AbstractButton {
        id: button
        anchors.fill: parent
        padding: 0
        hoverEnabled: true
        text: Translation.tr("Command Center")
        readonly property bool panelOpen: GlobalStates.sidebarRightOpen
        onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

        background: Rectangle {
            radius: Appearance.rounding.windowRounding
            color: button.panelOpen ? Appearance.colors.colSecondaryContainer
                : button.hovered ? Appearance.colors.colLayer1Hover : "transparent"
        }

        contentItem: MaterialSymbol {
            text: "instant_mix"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            iconSize: Appearance.font.pixelSize.larger
            color: button.panelOpen ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
        }
    }
}
