import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar as Bar
import QtQuick

Bar.Media {
    id: root
    compact: true

    Bar.StyledPopup {
        hoverTarget: root
        active: !root.panelOpen && !Config.options.bar.tooltips.clickToShow && root.containsMouse

        Column {
            anchors.centerIn: parent
            spacing: 4

            Bar.StyledPopupHeaderRow {
                icon: "music_note"
                label: Translation.tr("Media")
            }

            StyledText {
                color: Appearance.colors.colOnSurfaceVariant
                text: root.artist ? root.cleanedTitle + "\n" + root.artist : root.cleanedTitle
                textFormat: Text.PlainText
            }
        }
    }
}
