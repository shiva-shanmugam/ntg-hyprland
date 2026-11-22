import qs.modules.common.widgets

MaterialSymbol {
    id: root

    property string glyph: "device"
    readonly property var symbols: ({
        device: "devices_other", bluetooth: "bluetooth", earbuds: "earbuds",
        headphones: "headphones", speaker: "speaker", phone: "smartphone",
        laptop: "laptop", keyboard: "keyboard", mouse: "mouse", controller: "sports_esports",
        wifi: "wifi", battery: "battery_android_full", moon: "dark_mode",
        sun: "light_mode", volume: "volume_up", muted: "volume_off", mic: "mic",
        lock: "lock", power: "power_settings_new", plane: "flight", record: "fiber_manual_record",
        screenshot: "crop_free", cup: "coffee", profile: "speed", cpu: "developer_board",
        ram: "memory", play: "play_arrow", pause: "pause", next: "skip_next", previous: "skip_previous",
        bell: "notifications", settings: "settings", clock: "schedule", reboot: "restart_alt",
        close: "close", more: "more_horiz"
    })

    text: symbols[glyph] ?? glyph
    fill: 0
    iconSize: NothingMetrics.controlIconSize
    anchors.verticalCenterOffset: 1
}
