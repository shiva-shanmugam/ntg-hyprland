import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import "../../common/Palette.js" as Palette
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

MouseArea {
    id: root

    property bool compact: !Config.options.bar.verbose
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playing: activePlayer?.isPlaying ?? false
    readonly property bool panelOpen: GlobalStates.mediaControlsOpen
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property string artist: activePlayer?.trackArtist ?? ""
    readonly property real duration: activePlayer?.length ?? 0
    readonly property real progress: duration > 0 ? Math.max(0, Math.min(1, activePlayer.position / duration)) : 0
    readonly property bool showDetails: !compact && width >= 76

    Layout.fillHeight: true
    implicitWidth: playbackTile.width + (compact ? 8 : 20 + Math.max(30, Math.min(174, Math.max(trackLabel.implicitWidth, artistLabel.implicitWidth))))
    implicitHeight: 32
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton | Qt.BackButton | Qt.ForwardButton

    Accessible.role: Accessible.Button
    Accessible.name: Translation.tr("Media controls")
    Accessible.description: root.artist ? root.cleanedTitle + " · " + root.artist : root.cleanedTitle
    Accessible.onPressAction: GlobalStates.mediaControlsOpen = !root.panelOpen

    onPressed: event => {
        if (event.button === Qt.LeftButton)
            GlobalStates.mediaControlsOpen = !root.panelOpen;
        else if (event.button === Qt.MiddleButton)
            MprisController.togglePlaying();
        else if (event.button === Qt.BackButton)
            MprisController.previous();
        else if (event.button === Qt.RightButton || event.button === Qt.ForwardButton)
            MprisController.next();
    }

    Timer {
        running: root.playing && root.duration > 0
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.activePlayer?.positionChanged()
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.windowRounding
        color: root.panelOpen || root.containsMouse ? Palette.surface : "transparent"
    }

    Rectangle {
        id: playbackTile
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: root.showDetails ? undefined : parent.horizontalCenter
        anchors.left: root.showDetails ? parent.left : undefined
        anchors.leftMargin: 6
        width: 26
        height: width
        radius: Appearance.rounding.windowRounding
        color: Palette.raised
        border.width: 1
        border.color: root.panelOpen ? Palette.red : Palette.line

        MaterialSymbol {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: playbackProgress.visible ? -1 : 0
            text: root.playing ? "graphic_eq" : "music_note"
            iconSize: 17
            color: root.playing ? Palette.red : Palette.text
        }

        Rectangle {
            id: playbackProgress
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 5
                bottomMargin: 3
            }
            visible: root.duration > 0
            height: 2
            radius: 1
            color: Palette.line

            Rectangle {
                width: parent.width * root.progress
                height: parent.height
                radius: parent.radius
                color: Palette.red
            }
        }
    }

    ColumnLayout {
        anchors {
            left: playbackTile.right
            leftMargin: 8
            right: parent.right
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }
        visible: root.showDetails
        spacing: 0

        StyledText {
            id: trackLabel
            Layout.fillWidth: true
            text: root.cleanedTitle
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.pixelSize: 13
            color: Palette.text
        }

        StyledText {
            id: artistLabel
            Layout.fillWidth: true
            visible: root.artist.length > 0
            text: root.artist
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.pixelSize: 10
            color: Palette.muted
        }
    }
}
