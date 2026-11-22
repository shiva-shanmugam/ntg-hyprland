pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Bluetooth
import qs.services
import qs.modules.common
import "DeviceArt.js" as DeviceArt

Item {
    id: root
    required property bool panelOpen
    readonly property var devices: BluetoothStatus.connectedDevices
    property int selection: 0
    readonly property var selectedDevice: devices.length ? devices[selection % devices.length] : null
    readonly property bool connecting: BluetoothStatus.enabled
        && Bluetooth.devices.values.some(device => device.state === BluetoothDeviceState.Connecting)
    readonly property string deviceName: selectedDevice?.name || Persistent.states.sidebar.nothingBluetoothName
    readonly property string deviceArt: selectedDevice
        ? DeviceArt.glyph(selectedDevice.name, selectedDevice.icon)
        : Persistent.states.sidebar.nothingBluetoothArt
    readonly property var partBatteries: selectedDevice && deviceArt === "earbuds"
        ? DeviceArt.partsFor(selectedDevice, Bluetooth.devices.values) : []
    readonly property string statusText: {
        const status = !BluetoothStatus.available ? Translation.tr("No adapter")
            : connecting ? Translation.tr("Connecting")
            : !BluetoothStatus.enabled ? Translation.tr("Off")
            : selectedDevice ? Translation.tr("Connected")
            : deviceName ? Translation.tr("Last connected") : Translation.tr("No device connected");
        const battery = partBatteries.length
            ? partBatteries.map(part => part.side + " " + Math.round(part.value * 100) + "%").join(" · ")
            : selectedDevice?.batteryAvailable ? Math.round(selectedDevice.battery * 100) + "%" : "";
        return [deviceName, status, battery].filter(Boolean).join("\n");
    }

    function remember() {
        if (!Persistent.ready || !selectedDevice?.name)
            return;
        const state = Persistent.states.sidebar;
        if (state.nothingBluetoothName !== selectedDevice.name)
            state.nothingBluetoothName = selectedDevice.name;
        if (state.nothingBluetoothArt !== deviceArt)
            state.nothingBluetoothArt = deviceArt;
    }

    onSelectedDeviceChanged: remember()
    onDeviceArtChanged: remember()
    Component.onCompleted: remember()
    Connections {
        target: Persistent
        function onReadyChanged() { root.remember(); }
    }

    WheelHandler {
        enabled: root.devices.length > 1
        onWheel: event => {
            const delta = event.angleDelta.y || event.angleDelta.x;
            if (delta)
                root.selection = (root.selection + (delta > 0 ? 1 : root.devices.length - 1)) % root.devices.length;
            event.accepted = true;
        }
    }

    ControlGlyph {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 0
        glyph: BluetoothStatus.enabled ? root.deviceArt || "bluetooth" : "bluetooth_disabled"
        iconSize: 56
        color: root.selectedDevice ? DesktopPalette.red
            : BluetoothStatus.enabled ? DesktopPalette.text : DesktopPalette.muted
        SequentialAnimation on opacity {
            running: root.panelOpen && root.connecting
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: 415 }
            NumberAnimation { to: 1; duration: 415 }
        }
        Binding on opacity { when: !root.connecting; value: 1 }
    }
}
