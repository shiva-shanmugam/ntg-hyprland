import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower

Rectangle {
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)

    implicitWidth: contentItem.implicitWidth + root.horizontalPadding * 2
    implicitHeight: contentItem.implicitHeight + root.verticalPadding * 2
    radius: Appearance.rounding.surfaceRadius(width, height)
    color: Appearance.colors.colLayer0Base
    border.color: Appearance.colors.colOutlineVariant
    border.width: 1
    property real verticalPadding: 7
    property real horizontalPadding: 12

    Column {
        id: contentItem
        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
        }

        Loader {
            anchors {
                left: parent.left
                right: parent.right
            }
            visible: active
            active: Config.options.sidebar.quickSliders.showBrightness
            sourceComponent: QuickSlider {
                materialSymbol: "light_mode"
                label: Hyprsunset.gamma === 100 ? Translation.tr("Brightness") : Translation.tr("Gamma")
                enabled: !!root.brightnessMonitor
                split: 0.3
                value: Hyprsunset.gamma === 100? 0.3 + root.brightnessMonitor?.brightness * 0.7 : (Hyprsunset.gamma - Hyprsunset.gammaLowerLimit) / (100 - Hyprsunset.gammaLowerLimit) * 0.3
                tooltipContent: Hyprsunset.gamma === 100 ? `${Math.round(root.brightnessMonitor?.brightness * 100)}%` : `${Translation.tr("Gamma")} ${Hyprsunset.gamma}%`
                onMoved: {
                    if (value >= 0.3) {
                        // 0.3 - 1.0 brightness
                        root.brightnessMonitor.setBrightness((value - 0.3) / 0.7);
                        if (Hyprsunset.gamma !== 100) {
                            Hyprsunset.setGamma(100);
                        }
                    } else {
                        // 0 - 0.3 gamma
                        if (root.brightnessMonitor.brightness !== 0) {
                            root.brightnessMonitor.setBrightness(0);
                        }
                        Hyprsunset.setGamma((value / 0.3 * (100 - Hyprsunset.gammaLowerLimit) + Hyprsunset.gammaLowerLimit));
                    }
                }
            }
        }

        Loader {
            anchors {
                left: parent.left
                right: parent.right
            }
            visible: active
            active: Config.options.sidebar.quickSliders.showVolume
            sourceComponent: QuickSlider {
                materialSymbol: "volume_up"
                label: Translation.tr("Volume")
                enabled: !!Audio.sink?.audio
                value: Audio.sink?.audio?.volume ?? 0
                onMoved: {
                    Audio.sink.audio.volume = value
                }
            }
        }

        Loader {
            anchors {
                left: parent.left
                right: parent.right
            }
            visible: active
            active: Config.options.sidebar.quickSliders.showMic
            sourceComponent: QuickSlider {
                materialSymbol: "mic"
                label: Translation.tr("Microphone")
                enabled: !!Audio.source?.audio
                value: Audio.source?.audio?.volume ?? 0
                onMoved: {
                    Audio.source.audio.volume = value
                }
            }
        }
    }

    component QuickSlider: Slider {
        id: slider
        required property string materialSymbol
        required property string label
        property string tooltipContent: Math.round(value * 100) + "%"
        property real split: 0
        implicitHeight: 38
        leftPadding: 34
        rightPadding: Math.min(width * 0.28, 72)
        hoverEnabled: true
        Accessible.name: label
        ToolTip.visible: hovered || pressed
        ToolTip.text: label + "  " + tooltipContent

        background: Item {
            anchors.fill: parent
            MaterialSymbol {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: slider.materialSymbol
                iconSize: 18
                color: Appearance.colors.colOnLayer0
            }
            Row {
                id: meter
                height: 20
                anchors.left: parent.left
                anchors.leftMargin: slider.leftPadding
                anchors.right: parent.right
                anchors.rightMargin: slider.rightPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                readonly property int bars: Math.max(1, Math.min(32, Math.floor(width / 7)))
                Repeater {
                    model: meter.bars
                    Rectangle {
                        required property int index
                        width: Math.max(1, (meter.width - (meter.bars - 1) * meter.spacing) / meter.bars)
                        height: slider.split > 0 && index === Math.round(slider.split * (meter.bars - 1)) ? 16 : 10
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 2
                        color: index < Math.round(slider.visualPosition * meter.bars)
                            ? Appearance.colors.colOnLayer0 : Appearance.colors.colOutlineVariant
                    }
                }
            }
            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.family: Appearance.font.family.monospace
                font.pixelSize: 12
                color: Appearance.colors.colOnLayer0
                text: slider.tooltipContent
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * slider.availableWidth - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 19
            radius: 1
            visible: slider.pressed || slider.visualFocus
            color: Appearance.colors.colError
        }
    }
}
