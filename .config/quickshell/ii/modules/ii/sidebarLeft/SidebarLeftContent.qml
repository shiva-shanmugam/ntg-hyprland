import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.synchronizer

Item {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent
    property bool aiChatEnabled: Config.options.policies.ai !== 0
    property bool translatorEnabled: Config.options.sidebar.translator.enable
    property var tabButtonList: [
        ...(root.aiChatEnabled ? [
            {"icon": "graphic_eq", "name": Translation.tr("Chat")},
            {"icon": "terminal", "name": Translation.tr("Agent")}
        ] : []),
        ...(root.translatorEnabled ? [{"icon": "translate", "name": Translation.tr("Translator")}] : [])
    ]
    property int tabCount: swipeView.count

    function focusActiveItem() {
        swipeView.currentItem.forceActiveFocus()
    }

    Keys.onPressed: (event) => {
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                swipeView.incrementCurrentIndex()
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp) {
                swipeView.decrementCurrentIndex()
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: sidebarPadding
        }
        spacing: sidebarPadding

        GraphiteHeader {
            Layout.fillWidth: true
            readonly property bool chatSelected: root.aiChatEnabled && swipeView.currentIndex === 0
            readonly property bool agentSelected: root.aiChatEnabled && swipeView.currentIndex === 1
            title: chatSelected ? Translation.tr("Assistant") : (root.tabButtonList[swipeView.currentIndex]?.name ?? Translation.tr("Workspace"))
            detail: {
                if (agentSelected) return ConfigAgent.modelName + "  ·  " + Translation.tr("Local tasks");
                if (!chatSelected) return Translation.tr("Online translation");
                const model = Ai.getModel();
                if (!model) return Ai.discovering ? Translation.tr("Looking for local models…") : Translation.tr("No model selected");
                const state = Ai.busy ? Translation.tr("Replying…") : Ai.awaitingApproval ? Translation.tr("Awaiting approval")
                    : Ai.statusError ? Translation.tr("Request failed") : Ai.isLocal(model.endpoint) ? Translation.tr("Local") : Translation.tr("Online");
                return model.name + "  ·  " + (model.fixedReasoning && state === Translation.tr("Local")
                    ? Translation.tr("Local reasoning") : state);
            }
        }

        Toolbar {
            visible: tabButtonList.length > 0
            Layout.alignment: Qt.AlignHCenter
            enableShadow: false
            ToolbarTabBar {
                id: tabBar
                Layout.alignment: Qt.AlignHCenter
                tabButtonList: root.tabButtonList
                currentIndex: swipeView.currentIndex
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: swipeView.implicitWidth
            implicitHeight: swipeView.implicitHeight
            radius: Appearance.rounding.surfaceRadius(width, height)
            color: Appearance.colors.colLayer0Base
            border.color: Appearance.colors.colOutlineVariant
            border.width: 1

            SwipeView { // Content pages
                id: swipeView
                anchors.fill: parent
                spacing: 10
                currentIndex: tabBar.currentIndex

                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: swipeView.width
                        height: swipeView.height
                        radius: Appearance.rounding.surfaceRadius(width, height)
                    }
                }

                contentChildren: [
                    ...(root.aiChatEnabled ? [aiChat.createObject(), agent.createObject()] : []),
                    ...(root.translatorEnabled ? [translator.createObject()] : []),
                    ...(root.tabButtonList.length === 0 ? [placeholder.createObject()] : [])
                ]
            }
        }

        Component {
            id: aiChat
            AiChat {}
        }
        Component {
            id: agent
            AgentPanel {}
        }
        Component {
            id: translator
            Translator {}
        }
        Component {
            id: placeholder
            Item {
                StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Assistant and Translator are disabled")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}