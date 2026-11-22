pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import "../../common/Palette.js" as Palette
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Mpris

Item {
    id: root

    required property MprisPlayer player
    property list<real> visualizerPoints: []
    readonly property bool playing: player?.isPlaying ?? false
    readonly property real duration: Math.max(0, player?.length ?? 0)
    readonly property real position: Math.max(0, player?.position ?? 0)
    readonly property string artist: player?.trackArtist ?? ""

    component TransportButton: Button {
        id: control
        required property string symbol
        property bool primary: false

        implicitWidth: primary ? 34 : 28
        implicitHeight: 32
        hoverEnabled: true
        opacity: enabled ? 1 : 0.35

        background: Rectangle {
            radius: Appearance.rounding.windowRounding
            color: control.down ? Palette.raised : control.primary ? Palette.red
                : control.hovered ? Palette.raised : Palette.surface
            border.width: 1
            border.color: control.visualFocus ? Palette.text : control.primary ? Palette.red : Palette.line
        }

        contentItem: MaterialSymbol {
            text: control.symbol
            iconSize: 20
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Palette.text
        }

        StyledToolTip {
            text: control.text
        }
    }

    Timer {
        running: root.playing && root.duration > 0
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    StyledRectangularShadow {
        target: panel
    }

    PanelSurface {
        id: panel
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 2
            height: 24
            clip: true
            visible: root.playing && root.visualizerPoints.length > 1

            WaveVisualizer {
                live: root.playing
                points: root.visualizerPoints
                color: Palette.red
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 14

            Rectangle {
                id: artwork
                Layout.fillHeight: true
                Layout.preferredWidth: Math.max(0, panel.height - 24)
                radius: Appearance.rounding.windowRounding
                color: Palette.surface
                border.width: 1
                border.color: Palette.line

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: "album"
                    iconSize: 34
                    color: Palette.muted
                }

                StyledImage {
                    id: cover
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.player?.trackArtUrl || ""
                    fillMode: Image.PreserveAspectCrop
                    retainWhileLoading: false
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: cover.width
                            height: cover.height
                            radius: artwork.radius - 1
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        width: 6
                        height: 6
                        radius: width / 2
                        color: root.playing ? Palette.red : "transparent"
                        border.width: 1
                        border.color: root.playing ? Palette.red : Palette.muted
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.player?.identity || Translation.tr("Media")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: 10
                        color: Palette.muted
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || Translation.tr("Unknown Title")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.pixelSize: 17
                    color: Palette.text
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.artist.length > 0
                    text: root.artist
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    color: Palette.muted
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    TransportButton {
                        symbol: "skip_previous"
                        text: Translation.tr("Previous track")
                        enabled: root.player?.canGoPrevious ?? false
                        onClicked: root.player?.previous()
                    }

                    TransportButton {
                        primary: true
                        symbol: root.playing ? "pause" : "play_arrow"
                        text: root.playing ? Translation.tr("Pause") : Translation.tr("Play")
                        enabled: root.player?.canTogglePlaying ?? false
                        onClicked: root.player?.togglePlaying()
                    }

                    TransportButton {
                        symbol: "skip_next"
                        text: Translation.tr("Next track")
                        enabled: root.player?.canGoNext ?? false
                        onClicked: root.player?.next()
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        spacing: 0

                        Slider {
                            id: seek
                            Layout.fillWidth: true
                            implicitHeight: 16
                            leftPadding: 4
                            rightPadding: 4
                            from: 0
                            to: Math.max(1, root.duration)
                            stepSize: 1
                            value: root.position
                            enabled: root.duration > 0 && (root.player?.canSeek ?? false)
                            hoverEnabled: true
                            Accessible.name: Translation.tr("Playback position")
                            onMoved: root.player.position = value

                            background: Rectangle {
                                x: seek.leftPadding
                                y: (seek.height - height) / 2
                                width: seek.availableWidth
                                height: 3
                                radius: height / 2
                                color: Palette.line

                                Rectangle {
                                    width: root.duration > 0 ? parent.width * seek.visualPosition : 0
                                    height: parent.height
                                    radius: parent.radius
                                    color: Palette.red
                                }
                            }

                            handle: Rectangle {
                                x: seek.leftPadding + seek.visualPosition * seek.availableWidth - width / 2
                                y: (seek.height - height) / 2
                                implicitWidth: 7
                                implicitHeight: 7
                                radius: width / 2
                                visible: seek.enabled
                                color: seek.hovered || seek.pressed || seek.visualFocus ? Palette.text : Palette.red
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            StyledText {
                                Layout.fillWidth: true
                                text: StringUtils.friendlyTimeForSeconds(root.position)
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: 10
                                color: Palette.muted
                            }

                            StyledText {
                                visible: root.duration > 0
                                text: StringUtils.friendlyTimeForSeconds(root.duration)
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: 10
                                color: Palette.muted
                            }
                        }
                    }
                }
            }
        }
    }
}
