pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.notifications
import qs.modules.ii.sidebarRight.volumeMixer
import qs.modules.ii.sidebarRight.wifiNetworks
import "DeviceArt.js" as DeviceArt

Rectangle {
    id: root

    required property string kind
    signal dismiss()
    property var scanningAdapter: null
    radius: NothingMetrics.cardRadius
    color: Qt.alpha(DesktopPalette.panel, DesktopPalette.dark ? 0.84 : 0.9)

    function releaseScan() {
        if (scanningAdapter)
            scanningAdapter.discovering = false;
        scanningAdapter = null;
    }

    function refresh() {
        releaseScan();
        if (kind === "bluetooth") {
            const adapter = Bluetooth.defaultAdapter;
            if (adapter?.enabled && !adapter.discovering) {
                scanningAdapter = adapter;
                adapter.discovering = true;
            }
        } else if (kind === "wifi" && Network.wifiEnabled) {
            Network.rescanWifi();
        } else if (kind === "notifications") {
            Notifications.markAllRead();
        }
    }

    Component.onCompleted: refresh()
    Component.onDestruction: releaseScan()
    onKindChanged: refresh()

    readonly property var titles: ({
        bluetooth: Translation.tr("Bluetooth devices"),
        wifi: Translation.tr("Wi-Fi networks"),
        audio: Translation.tr("Audio output"),
        mic: Translation.tr("Audio input"),
        notifications: Translation.tr("Notifications")
    })

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: NothingMetrics.padding
        spacing: NothingMetrics.gap

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: root.titles[root.kind] ?? ""
                font.family: Appearance.font.family.monospace
                font.pixelSize: 15
                color: DesktopPalette.text
            }

            ControlIconButton {
                glyph: "close"
                text: Translation.tr("Close details")
                onClicked: root.dismiss()
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: ({
                bluetooth: bluetoothList,
                wifi: wifiList,
                audio: devices,
                mic: devices,
                notifications: notifications
            })[root.kind] ?? null
        }
    }

    Component {
        id: bluetoothList
        Item {
            ListView {
                id: connectedList
                anchors.fill: parent
                clip: true
                spacing: NothingMetrics.tight
                model: BluetoothStatus.enabled ? BluetoothStatus.friendlyDeviceList : []

                delegate: Button {
                    id: deviceRow
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: NothingMetrics.unit / 2
                    hoverEnabled: true
                    enabled: BluetoothStatus.enabled && modelData.state !== BluetoothDeviceState.Connecting
                        && modelData.state !== BluetoothDeviceState.Disconnecting
                    text: modelData.name
                    onClicked: {
                        if (modelData.connected) modelData.disconnect();
                        else modelData.connect();
                    }

                    background: Rectangle {
                        radius: NothingMetrics.squareRadius
                        color: deviceRow.hovered ? DesktopPalette.raised : DesktopPalette.surface
                        border.width: NothingMetrics.hairline
                        border.color: deviceRow.visualFocus ? DesktopPalette.text : DesktopPalette.line
                    }

                    contentItem: RowLayout {
                        spacing: NothingMetrics.gap
                        ControlGlyph {
                            glyph: DeviceArt.glyph(deviceRow.modelData.name, deviceRow.modelData.icon)
                            color: DesktopPalette.text
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: deviceRow.text
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: 12
                            color: DesktopPalette.text
                        }
                        StyledText {
                            text: deviceRow.modelData.connected ? Translation.tr("Disconnect")
                                : deviceRow.modelData.state === BluetoothDeviceState.Connecting
                                  ? Translation.tr("Connecting") : Translation.tr("Connect")
                            font.pixelSize: 11
                            color: DesktopPalette.muted
                        }
                    }
                }
            }
            StyledText {
                anchors.centerIn: parent
                visible: connectedList.count === 0
                text: !BluetoothStatus.available ? Translation.tr("No Bluetooth adapter")
                    : !BluetoothStatus.enabled ? Translation.tr("Bluetooth is off")
                    : Bluetooth.defaultAdapter?.discovering ? Translation.tr("Looking for devices") : Translation.tr("No devices")
                color: DesktopPalette.muted
                font.family: Appearance.font.family.monospace
            }
        }
    }

    Component {
        id: wifiList
        Item {
            ListView {
                id: networks
                anchors.fill: parent
                clip: true
                model: Network.wifiEnabled ? Network.friendlyWifiNetworks : []
                delegate: WifiNetworkItem {
                    required property WifiAccessPoint modelData
                    width: ListView.view.width
                    wifiNetwork: modelData
                }
            }
            StyledText {
                anchors.centerIn: parent
                visible: networks.count === 0
                text: !Network.wifiEnabled ? Translation.tr("Wi-Fi is off")
                    : Network.wifiScanning ? Translation.tr("Scanning") : Translation.tr("No networks")
                color: DesktopPalette.muted
                font.family: Appearance.font.family.monospace
            }
        }
    }

    Component {
        id: devices
        VolumeDialogContent { isSink: root.kind === "audio" }
    }

    Component {
        id: notifications
        NotificationList {}
    }
}
