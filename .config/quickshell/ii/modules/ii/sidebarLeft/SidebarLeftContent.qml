import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root
    required property var scopeRoot
    anchors.fill: parent

    readonly property bool aiEnabled: Config.options.policies.ai !== 0
    readonly property bool translatorEnabled: Config.options.sidebar.translator.enable
    readonly property var tabs: [
        ...(aiEnabled ? [
            { key: "chat", icon: "graphic_eq", name: Translation.tr("Chat"), page: chatPage },
            { key: "agent", icon: "terminal", name: Translation.tr("Agent"), page: agentPage }
        ] : []),
        ...(translatorEnabled ? [
            { key: "translator", icon: "translate", name: Translation.tr("Translator"), page: translatorPage }
        ] : [])
    ]
    readonly property var currentTab: tabs[pages.currentIndex]
    readonly property color tileFill: Qt.alpha(DesktopPalette.panel, DesktopPalette.dark ? 0.66 : 0.75)

    function focusActiveItem() {
        pages.currentItem?.item?.forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (event.modifiers !== Qt.ControlModifier)
            return;
        if (event.key === Qt.Key_PageDown) {
            pages.incrementCurrentIndex();
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            pages.decrementCurrentIndex();
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 10

        Item {
            Layout.fillWidth: true
            implicitHeight: 66

            TileShadow { target: header }
            Rectangle {
                id: header
                anchors.fill: parent
                radius: 17
                color: root.tileFill

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: width / 2
                        color: DesktopPalette.red
                        MaterialSymbol {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1
                            text: root.currentTab?.icon ?? "widgets"
                            color: DesktopPalette.onAccent
                            iconSize: 24
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: root.currentTab?.key === "chat" ? Translation.tr("Assistant")
                                : root.currentTab?.name ?? ""
                            font.family: Appearance.font.family.title
                            font.pixelSize: 23
                            font.weight: Font.DemiBold
                            color: DesktopPalette.text
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: {
                                if (root.currentTab?.key === "agent")
                                    return ConfigAgent.modelName + " · " + Translation.tr("Local tasks");
                                if (root.currentTab?.key === "translator")
                                    return Translation.tr("Online translation");
                                if (root.currentTab?.key !== "chat")
                                    return "";
                                const model = Ai.getModel();
                                if (!model)
                                    return Ai.discovering ? Translation.tr("Looking for local models…") : Translation.tr("No model selected");
                                const state = Ai.busy ? Translation.tr("Replying…") : Ai.awaitingApproval ? Translation.tr("Awaiting approval")
                                    : Ai.statusError ? Translation.tr("Request failed") : Ai.isLocal(model.endpoint) ? Translation.tr("Local") : Translation.tr("Online");
                                return model.name + " · " + (model.fixedReasoning && state === Translation.tr("Local")
                                    ? Translation.tr("Local reasoning") : state);
                            }
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: 11
                            color: DesktopPalette.muted
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.tabs.length > 1
            spacing: 8

            Repeater {
                model: root.tabs
                delegate: Button {
                    id: tab
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 40
                    hoverEnabled: true
                    text: modelData.name
                    readonly property bool selected: pages.currentIndex === index
                    onClicked: pages.setCurrentIndex(index)

                    background: Item {
                        TileShadow { target: face }
                        Rectangle {
                            id: face
                            anchors.fill: parent
                            radius: 17
                            color: tab.selected ? DesktopPalette.red
                                : tab.hovered ? DesktopPalette.surface : root.tileFill
                            border.width: tab.visualFocus ? 1 : 0
                            border.color: tab.selected ? DesktopPalette.onAccent : DesktopPalette.red
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 6
                        Item { Layout.fillWidth: true }
                        MaterialSymbol {
                            text: tab.modelData.icon
                            iconSize: 20
                            color: tab.selected ? DesktopPalette.onAccent : DesktopPalette.text
                        }
                        StyledText {
                            Layout.maximumWidth: Math.max(0, tab.width - 44)
                            text: tab.text
                            elide: Text.ElideRight
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: 12
                            color: tab.selected ? DesktopPalette.onAccent : DesktopPalette.text
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TileShadow { target: body }
            Rectangle {
                id: body
                anchors.fill: parent
                radius: 17
                color: Qt.alpha(DesktopPalette.panel, DesktopPalette.dark ? 0.84 : 0.9)

                SwipeView {
                    id: pages
                    anchors.fill: parent
                    spacing: 10
                    clip: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: pages.width
                            height: pages.height
                            radius: body.radius
                        }
                    }

                    Repeater {
                        model: root.tabs
                        delegate: Loader {
                            required property var modelData
                            sourceComponent: modelData.page
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.tabs.length === 0
                    text: Translation.tr("Assistant and Translator are disabled")
                    color: DesktopPalette.muted
                }
            }
        }
    }

    Component { id: chatPage; AiChat {} }
    Component { id: agentPage; AgentPanel {} }
    Component { id: translatorPage; Translator {} }
}
