pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

FocusScope {
    id: root

    default property alias content: tileContent.data
    property string shape: "card"
    property string label: ""
    property string summary: ""
    property bool selected: false
    property bool alert: false
    property string tone: ""
    property bool interactive: true
    property bool hasDetails: false
    property bool panelOpen: false
    property int order: 0
    signal activated()
    signal detailsRequested()

    readonly property bool solidRed: tone === "red" || (selected && (alert || Config.options.sidebar.nothingActiveStyle === "red"))
    readonly property bool whiteRed: tone === "whiteRed" && !solidRed
    readonly property bool inverted: selected && !solidRed && !whiteRed
    readonly property color ink: solidRed ? DesktopPalette.onAccent
        : whiteRed ? DesktopPalette.red : inverted ? DesktopPalette.black : DesktopPalette.text
    property bool revealed: false

    onPanelOpenChanged: if (!panelOpen) revealed = false

    Timer {
        running: root.panelOpen && !root.revealed
        interval: 1 + Math.min(root.order, NothingMetrics.columns) * NothingMetrics.staggerMs
        onTriggered: root.revealed = true
    }

    opacity: revealed ? 1 : 0
    scale: action.down ? 0.96 : 1
    transform: Translate {
        x: root.revealed ? 0 : NothingMetrics.slideDistance
        Behavior on x { NumberAnimation { duration: NothingMetrics.animationMs; easing.type: Easing.OutQuad } }
    }
    Behavior on opacity { NumberAnimation { duration: NothingMetrics.animationMs; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: NothingMetrics.staggerMs * 8; easing.type: Easing.OutQuad } }

    TileShadow { target: surface }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: NothingMetrics.radius(root.shape, width, height)
        color: root.solidRed ? DesktopPalette.red : root.whiteRed ? DesktopPalette.onAccent
            : root.inverted ? DesktopPalette.text
            : Qt.alpha(hover.hovered ? DesktopPalette.surface : DesktopPalette.panel, DesktopPalette.dark ? 0.66 : 0.75)
        border.width: action.visualFocus ? NothingMetrics.hairline : 0
        border.color: root.ink
    }

    AbstractButton {
        id: action
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        text: root.label
        Accessible.description: root.summary
        focusPolicy: Qt.StrongFocus
        property bool held: false
        onPressed: held = false
        onClicked: if (!held) root.activated()
        onPressAndHold: if (root.hasDetails) {
            held = true;
            root.detailsRequested();
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Menu && root.hasDetails) {
                root.detailsRequested();
                event.accepted = true;
            }
        }
    }

    HoverHandler { id: hover }

    StyledToolTip {
        text: root.summary ? root.label + "\n" + root.summary : root.label
        delay: 550
        extraVisibleCondition: root.panelOpen && hover.hovered && !action.down && text.length > 0
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: root.hasDetails
        onTapped: root.detailsRequested()
    }

    Item {
        id: tileContent
        anchors.fill: parent
        anchors.margins: NothingMetrics.padding
    }
}
