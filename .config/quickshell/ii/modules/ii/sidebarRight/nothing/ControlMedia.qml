pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions

Item {
    id: root
    required property bool panelOpen
    readonly property var player: MprisController.activePlayer
    readonly property real duration: player?.length ?? 0
    readonly property real position: player?.position ?? 0
    readonly property string statusText: [
        StringUtils.cleanMusicTitle(player?.trackTitle) || Translation.tr("No track"),
        player?.trackArtist,
        player?.identity
    ].filter(Boolean).join("\n")

    Timer {
        running: root.panelOpen && (root.player?.isPlaying ?? false) && root.duration > 0
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    Row {
        anchors.centerIn: parent
        spacing: NothingMetrics.tight

        ControlIconButton {
            glyph: "previous"
            glyphSize: 30
            text: Translation.tr("Previous track")
            enabled: MprisController.canGoPrevious
            onClicked: MprisController.previous()
        }

        ControlIconButton {
            glyph: root.player?.isPlaying ? "pause" : "play"
            glyphSize: 30
            text: root.player?.isPlaying ? Translation.tr("Pause") : Translation.tr("Play")
            enabled: MprisController.canTogglePlaying
            onClicked: MprisController.togglePlaying()
        }

        ControlIconButton {
            glyph: "next"
            glyphSize: 30
            text: Translation.tr("Next track")
            enabled: MprisController.canGoNext
            onClicked: MprisController.next()
        }
    }

    DotLevel {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.duration > 0
        enabled: root.player?.canSeek ?? false
        alert: root.player?.isPlaying ?? false
        value: root.duration > 0 ? Math.max(0, Math.min(1, root.position / root.duration)) : 0
        Accessible.name: Translation.tr("Playback position")
        onMoved: root.player.position = value * root.duration
    }
}
