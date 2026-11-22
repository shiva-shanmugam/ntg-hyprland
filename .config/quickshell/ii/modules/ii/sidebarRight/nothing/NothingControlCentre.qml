pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models.quickToggles
import "TileLayout.js" as TileLayout

Item {
    id: root

    property bool opened: GlobalStates.sidebarRightOpen
    property point inputOrigin: Qt.point(x, y)
    readonly property var placement: TileLayout.pack(TileLayout.tiles, NothingMetrics.columns)
    readonly property real gridWidth: NothingMetrics.span(NothingMetrics.columns)
    readonly property real gridHeight: NothingMetrics.span(placement.rowCount)
    readonly property var screen: root.QsWindow.window?.screen
    readonly property var brightness: screen ? Brightness.getMonitorForScreen(screen) : null
    readonly property bool sinkReady: !!Audio.sink?.audio
    readonly property bool micReady: !!Audio.source?.audio
    readonly property bool bluetoothReady: BluetoothStatus.available

    property string details: ""
    property string armed: ""
    signal dismiss()

    function openDetails(name) {
        armed = "";
        details = name;
    }

    function powerAction(name, action) {
        if (armed !== name) {
            armed = name;
            confirmTimer.restart();
            return;
        }
        armed = "";
        dismiss();
        action();
    }

    function handleEscape() {
        if (details) details = "";
        else if (armed) armed = "";
        else dismiss();
    }

    onOpenedChanged: if (!opened) {
        details = "";
        armed = "";
        confirmTimer.stop();
    }

    Keys.priority: Keys.BeforeItem
    Keys.onEscapePressed: handleEscape()

    Timer {
        id: confirmTimer
        interval: NothingMetrics.armMs
        onTriggered: root.armed = ""
    }

    Loader {
        id: profiles
        active: NothingControlActions.profileAvailable
        sourceComponent: PowerProfilesToggle {}
    }
    ScreenSnipToggle { id: capture }

    readonly property var entries: ({
        bluetooth: {
            title: Translation.tr("Bluetooth"), enabled: root.bluetoothReady, details: "bluetooth",
            activate: () => { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled; }
        },
        wifi: { title: Translation.tr("Wi-Fi"), selected: Network.wifiEnabled, alert: true,
            glyph: Network.wifiEnabled ? (Network.active ? Network.materialSymbol : "wifi") : "wifi_off",
            summary: Network.wifiEnabled
                ? Network.active?.ssid || (Network.wifiConnecting ? Translation.tr("Connecting") : Translation.tr("Disconnected"))
                : Translation.tr("Off"),
            details: "wifi", activate: () => Network.toggleWifi() },
        volume: { title: Translation.tr("Volume"), details: "audio" },
        brightness: { title: Translation.tr("Brightness") },
        media: { title: Translation.tr("Media") },
        clock: { title: Translation.tr("Clock"), glyph: "clock", summary: DateTime.time },
        battery: {
            title: Translation.tr("Battery"),
            glyph: !Battery.available ? "battery_unknown" : Battery.isCharging ? "battery_charging_full"
                : Battery.isLow ? "battery_alert" : "battery",
            summary: Battery.available ? Math.round(Battery.percentage * 100) + "%" : "",
            warning: Battery.isLow && !Battery.isCharging
        },
        mic: { title: Translation.tr("Mic"), glyph: root.micReady && !Audio.source.audio.muted ? "mic" : "mic_off",
            selected: root.micReady && !Audio.source.audio.muted,
            enabled: root.micReady, details: "mic", activate: () => { if (root.micReady) Audio.toggleMicMute(); } },
        dnd: { title: Translation.tr("DND"), glyph: "do_not_disturb_on", selected: Notifications.silent, alert: true,
            activate: () => Notifications.silent = !Notifications.silent },
        night: { title: Translation.tr("Night light"), glyph: "nightlight", selected: Hyprsunset.temperatureActive,
            activate: () => Hyprsunset.toggleTemperature() },
        airplane: { title: Translation.tr("Airplane"), glyph: "plane", selected: NothingControlActions.airplaneMode,
            activate: () => NothingControlActions.toggleAirplane() },
        record: { title: NothingControlActions.recording ? Translation.tr("Stop rec") : Translation.tr("Record"),
            glyph: "record", selected: NothingControlActions.recording, alert: true,
            activate: () => NothingControlActions.record() },
        screenshot: { title: Translation.tr("Screenshot"), glyph: "screenshot", activate: () => capture.mainAction() },
        caffeine: { title: Translation.tr("Stay awake"), glyph: "cup", selected: Idle.inhibit,
            activate: () => Idle.toggleInhibit() },
        profile: { title: profiles.item?.statusText ? Translation.tr(profiles.item.statusText) : Translation.tr("Profiles off"),
            glyph: "profile",
            enabled: NothingControlActions.profileAvailable, selected: NothingControlActions.profileAvailable && PowerProfiles.profile === PowerProfile.PowerSaver,
            alert: true, activate: () => profiles.item?.mainAction() },
        cpu: { title: Translation.tr("CPU"), glyph: "cpu", summary: Math.round(ResourceUsage.cpuUsage * 100) + "%" },
        ram: { title: Translation.tr("RAM"), glyph: "ram", summary: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%" },
        playback: { title: MprisController.isPlaying ? Translation.tr("Pause") : Translation.tr("Play"),
            glyph: MprisController.isPlaying ? "pause" : "play", selected: MprisController.isPlaying,
            enabled: MprisController.canTogglePlaying, activate: () => MprisController.togglePlaying() },
        scheme: { title: DesktopPalette.dark ? Translation.tr("Dark mode") : Translation.tr("Light mode"),
            glyph: DesktopPalette.dark ? "moon" : "sun", selected: DesktopPalette.dark,
            activate: () => MaterialThemeLoader.toggleLightDark() },
        notifications: { title: Translation.tr("Notifications"),
            glyph: Notifications.unread > 0 ? "notifications_active" : "bell", tone: "whiteRed",
            summary: String(Notifications.list.length),
            activate: () => root.openDetails("notifications") },
        settings: { title: Translation.tr("Settings"), glyph: "settings", tone: "whiteRed", alternate: () => {
                Quickshell.execDetached(["hyprctl", "reload"]);
                Quickshell.reload(false);
            }, activate: () => {
                root.dismiss();
                Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("settings.qml")]);
            } },
        session: { title: Translation.tr("Session"), glyph: "logout", activate: () => {
                root.dismiss();
                GlobalStates.sessionOpen = true;
            } },
        lock: { title: Translation.tr("Lock"), glyph: "lock",
            activate: () => root.powerAction("lock", () => Session.lock()) },
        sleep: { title: Translation.tr("Sleep"), glyph: "bedtime",
            activate: () => root.powerAction("sleep", () => Session.suspend()) },
        reboot: { title: Translation.tr("Restart"), glyph: "reboot",
            activate: () => root.powerAction("reboot", () => Session.reboot()) },
        power: { title: Translation.tr("Shutdown"), glyph: "power", tone: "red",
            activate: () => root.powerAction("power", () => Session.poweroff()) }
    })

    property Region inputRegion: Region {
        item: detailsLoader.active ? detailsLoader : null
        regions: root.placement.items.map(spot =>
            inputTile.createObject(root, { spot }))
    }

    property Component inputTile: Region {
        required property var spot
        readonly property real stride: NothingMetrics.unit + NothingMetrics.gap
        readonly property real rawTop: spot.row * stride - grid.contentY
        readonly property int rawHeight: NothingMetrics.span(spot.tall)

        x: root.inputOrigin.x + grid.x + spot.col * stride
        y: root.inputOrigin.y + grid.y + Math.max(0, rawTop)
        width: root.details ? 0 : NothingMetrics.span(spot.wide)
        height: Math.max(0, Math.min(grid.height, rawTop + rawHeight) - Math.max(0, rawTop))
        shape: spot.shape === "circle" && height === rawHeight ? RegionShape.Ellipse : RegionShape.Rect
    }

    Flickable {
        id: grid
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.gridWidth
        height: Math.max(0, Math.min(root.height, root.gridHeight))
        contentWidth: width
        contentHeight: root.gridHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        visible: !root.details
        clip: contentHeight > height

        Repeater {
            model: root.placement.items
            delegate: NothingTile {
                id: tile
                required property var modelData
                required property int index
                readonly property string type: modelData.type
                readonly property var entry: root.entries[type] ?? {}
                readonly property bool confirming: root.armed === type

                x: modelData.col * (NothingMetrics.unit + NothingMetrics.gap)
                y: modelData.row * (NothingMetrics.unit + NothingMetrics.gap)
                width: NothingMetrics.span(modelData.wide)
                height: NothingMetrics.span(modelData.tall)
                shape: modelData.shape
                order: index
                panelOpen: root.opened

                label: confirming ? Translation.tr("Confirm %1").arg(entry.title) : (entry.title ?? "")
                summary: confirming ? "" : body.item?.statusText ?? entry.summary ?? ""
                interactive: (!!entry.activate || !!entry.details) && (entry.enabled ?? true)
                selected: confirming || (entry.selected ?? false)
                alert: confirming || (entry.alert ?? false)
                tone: entry.tone ?? ""
                hasDetails: !!entry.details || !!entry.alternate
                onActivated: entry.activate?.()
                onDetailsRequested: {
                    if (entry.details) root.openDetails(entry.details);
                    else entry.alternate?.();
                }

                Loader {
                    id: body
                    anchors.fill: parent
                    sourceComponent: ({
                        bluetooth: bluetooth,
                        volume: level,
                        brightness: level,
                        media: media
                    })[tile.type] ?? small
                }

                Component {
                    id: bluetooth
                    BluetoothTile {
                        panelOpen: root.opened && !root.details
                    }
                }

                Component {
                    id: media
                    ControlMedia { panelOpen: root.opened && !root.details }
                }

                Component {
                    id: level
                    Item {
                        id: slider
                        readonly property bool sound: tile.type === "volume"
                        readonly property bool available: sound ? root.sinkReady : !!root.brightness?.ready
                        readonly property real value: sound ? Audio.value : (root.brightness?.brightness ?? 0)
                        readonly property bool muted: sound && (Audio.sink?.audio?.muted ?? false)
                        readonly property string statusText: available
                            ? Math.round(value * 100) + "%" + (sound ? "\n" + Audio.friendlyDeviceName(Audio.sink) : "")
                            : (sound ? Translation.tr("No audio output") : Translation.tr("No backlight"))

                        ControlIconButton {
                            anchors.centerIn: parent
                            visible: slider.sound
                            glyph: slider.muted ? "muted" : "volume"
                            glyphSize: NothingMetrics.controlIconSize
                            text: slider.muted ? Translation.tr("Unmute output") : Translation.tr("Mute output")
                            enabled: slider.available
                            ink: slider.muted ? DesktopPalette.red : tile.ink
                            onClicked: Audio.toggleMute()
                        }

                        ControlGlyph {
                            anchors.centerIn: parent
                            visible: !slider.sound
                            glyph: "sun"
                            color: slider.available ? tile.ink : DesktopPalette.muted
                        }

                        DotLevel {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            value: slider.value
                            enabled: slider.available
                            alert: slider.muted || slider.value > 1
                            Accessible.name: tile.label
                            onMoved: {
                                if (slider.sound) Audio.sink.audio.volume = value;
                                else root.brightness?.setBrightness(value);
                            }
                        }
                    }
                }

                Component {
                    id: small
                    Item {
                        ControlGlyph {
                            anchors.centerIn: parent
                            glyph: tile.confirming ? "check" : (tile.entry.glyph ?? "")
                            color: tile.entry.warning ? DesktopPalette.red
                                : tile.entry.enabled === false ? DesktopPalette.muted : tile.ink
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: detailsLoader
        anchors.right: parent.right
        anchors.top: parent.top
        active: !!root.details
        width: root.gridWidth
        height: Math.max(0, Math.min(root.height, NothingMetrics.span(5)))
        sourceComponent: ControlDetails {
            kind: root.details
            onDismiss: root.details = ""
        }
    }
}
