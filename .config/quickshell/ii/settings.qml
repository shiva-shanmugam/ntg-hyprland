//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

ApplicationWindow {
    id: root
    visible: true
    onClosing: Qt.quit()
    title: "ntg-hyprland settings"
    minimumWidth: 750
    minimumHeight: 500
    width: 1100
    height: 750
    color: DesktopPalette.black
    property int currentPage: 0
    readonly property url configUrl: Directories.config + "/illogical-impulse/config.json"
    property var pages: [
        {
            name: Translation.tr("Quick"),
            icon: "tune",
            component: "modules/settings/QuickConfig.qml"
        },
        {
            name: Translation.tr("General"),
            icon: "browse",
            component: "modules/settings/GeneralConfig.qml"
        },
        {
            name: Translation.tr("Bar"),
            icon: "toast",
            iconRotation: 180,
            component: "modules/settings/BarConfig.qml"
        },
        {
            name: Translation.tr("Background"),
            icon: "texture",
            component: "modules/settings/BackgroundConfig.qml"
        },
        {
            name: Translation.tr("Interface"),
            icon: "bottom_app_bar",
            component: "modules/settings/InterfaceConfig.qml"
        },
        {
            name: Translation.tr("Services"),
            icon: "settings",
            component: "modules/settings/ServicesConfig.qml"
        },
        {
            name: Translation.tr("Advanced"),
            icon: "construction",
            component: "modules/settings/AdvancedConfig.qml"
        },
        {
            name: Translation.tr("About"),
            icon: "info",
            component: "modules/settings/About.qml"
        }
    ]

    palette.window: DesktopPalette.black
    palette.windowText: DesktopPalette.text
    palette.base: DesktopPalette.panel
    palette.text: DesktopPalette.text
    palette.button: DesktopPalette.surface
    palette.buttonText: DesktopPalette.text
    palette.highlight: DesktopPalette.red
    palette.highlightedText: DesktopPalette.onAccent

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme();
        Config.readWriteDelay = 0;
    }

    function movePage(delta: int, wrap: bool): void {
        const next = currentPage + delta;
        currentPage = wrap ? (next + pages.length) % pages.length : Math.max(0, Math.min(next, pages.length - 1));
    }

    Shortcut { sequence: "Ctrl+PageDown"; onActivated: root.movePage(1, false) }
    Shortcut { sequence: "Ctrl+PageUp"; onActivated: root.movePage(-1, false) }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: root.movePage(1, true) }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: root.movePage(-1, true) }

    component RailButton: Button {
        id: control
        property string glyph
        property bool selected: false
        Layout.fillWidth: true
        implicitHeight: 40
        hoverEnabled: true
        leftPadding: 12
        rightPadding: 8

        background: Rectangle {
            radius: Appearance.rounding.windowRounding
            color: control.selected || control.hovered ? DesktopPalette.surface : "transparent"
            border.width: control.selected || control.visualFocus ? 1 : 0
            border.color: control.visualFocus ? DesktopPalette.red : DesktopPalette.line

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                visible: control.selected
                width: 3
                height: 16
                radius: 1.5
                color: DesktopPalette.red
            }
        }

        contentItem: RowLayout {
            spacing: 10
            MaterialSymbol {
                text: control.glyph
                iconSize: 21
                fill: 0
                color: control.selected ? DesktopPalette.red : DesktopPalette.muted
            }
            StyledText {
                Layout.fillWidth: true
                text: control.text
                font.family: Appearance.font.family.monospace
                font.pixelSize: 13
                color: control.selected || control.hovered ? DesktopPalette.text : DesktopPalette.muted
                elide: Text.ElideRight
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        PanelSurface {
            Layout.preferredWidth: Math.max(170, Math.min(210, root.width * 0.18))
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                RowLayout {
                    Layout.topMargin: 8
                    Layout.bottomMargin: 12
                    Layout.leftMargin: 4
                    spacing: 8
                    Rectangle { width: 7; height: 7; radius: 3.5; color: DesktopPalette.red }
                    StyledText {
                        text: "ntg-hyprland"
                        color: DesktopPalette.text
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                Repeater {
                    model: root.pages
                    delegate: RailButton {
                        required property int index
                        required property var modelData
                        text: modelData.name
                        glyph: modelData.icon
                        selected: index === root.currentPage
                        onClicked: root.currentPage = index
                    }
                }

                Item { Layout.fillHeight: true }

                RailButton {
                    id: configButton
                    glyph: "edit_document"
                    text: copied ? Translation.tr("Path copied") : Translation.tr("Config file")
                    property bool copied: false
                    onClicked: Qt.openUrlExternally(root.configUrl)
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: {
                            Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(root.configUrl.toString());
                            configButton.copied = true;
                            copiedTimer.restart();
                        }
                    }
                    Timer {
                        id: copiedTimer
                        interval: 1500
                        onTriggered: configButton.copied = false
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 4
                Layout.topMargin: 7
                Layout.bottomMargin: 3

                StyledText {
                    Layout.fillWidth: true
                    text: root.pages[root.currentPage].name
                    color: DesktopPalette.text
                    font.family: Appearance.font.family.title
                    font.pixelSize: 28
                    font.bold: true
                }

                Button {
                    id: closeButton
                    visible: Config.options.windows.showTitlebar
                    implicitWidth: 34
                    implicitHeight: 34
                    text: Translation.tr("Close settings")
                    onClicked: root.close()
                    background: Rectangle {
                        radius: Appearance.rounding.windowRounding
                        color: closeButton.hovered ? DesktopPalette.raised : DesktopPalette.panel
                        border.color: closeButton.visualFocus ? DesktopPalette.red : DesktopPalette.line
                        border.width: 1
                    }
                    contentItem: MaterialSymbol {
                        text: "close"
                        iconSize: 19
                        color: closeButton.hovered ? DesktopPalette.red : DesktopPalette.muted
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Loader {
                Layout.minimumWidth: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: Config.ready
                source: root.pages[root.currentPage].component
            }
        }
    }
}
