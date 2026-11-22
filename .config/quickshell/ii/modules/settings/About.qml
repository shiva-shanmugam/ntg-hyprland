import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {

    ContentSection {
        icon: "terminal"
        title: Translation.tr("The dotfiles")

        StyledText {
            Layout.fillWidth: true
            text: "ntg-hyprland"
            font.family: Appearance.font.family.title
            font.pixelSize: 32
            font.bold: true
            color: DesktopPalette.text
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("A Nothing-inspired Hyprland desktop with a floating Control Center, graphite styling, and a local AI Agent.")
            color: DesktopPalette.muted
            wrapMode: Text.WordWrap
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            RippleButtonWithIcon {
                materialIcon: "code"
                mainText: Translation.tr("Project on GitHub")
                onClicked: Qt.openUrlExternally("https://github.com/shiva-shanmugam/ntg-hyprland")
            }
            RippleButtonWithIcon {
                materialIcon: "menu_book"
                mainText: Translation.tr("Installation guide")
                onClicked: Qt.openUrlExternally("https://github.com/shiva-shanmugam/ntg-hyprland/blob/main/docs/INSTALL.md")
            }
        }
    }

    ContentSection {
        icon: "favorite"
        title: Translation.tr("Credits")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Built on end-4’s illogical-impulse. The original Quickshell AI sidebar inspired our local Agent.")
            color: DesktopPalette.muted
            wrapMode: Text.WordWrap
        }

        RippleButtonWithIcon {
            materialIcon: "open_in_new"
            mainText: Translation.tr("end-4’s dotfiles")
            onClicked: Qt.openUrlExternally("https://github.com/end-4/dots-hyprland")
        }
    }

    ContentSection {
        icon: "computer"
        title: Translation.tr("System")

        StyledText {
            Layout.fillWidth: true
            text: SystemInfo.distroName
            color: DesktopPalette.text
            font.family: Appearance.font.family.monospace
        }
        StyledText {
            Layout.fillWidth: true
            text: "Hyprland · Quickshell"
            color: DesktopPalette.muted
        }
    }
}
