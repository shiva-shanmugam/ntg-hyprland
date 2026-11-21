pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: root

    property string project: ""
    property bool showDiff: false
    readonly property var job: ConfigAgent.snapshot
    readonly property bool busy: ConfigAgent.active || ConfigAgent.handlingRequest

    function submit() {
        if (ConfigAgent.start(taskInput.text, project, editFiles.checked, screenAccess.checked)) {
            taskInput.clear();
            editFiles.checked = false;
            screenAccess.checked = false;
            showDiff = false;
        }
    }

    onFocusChanged: if (focus) taskInput.forceActiveFocus()

    FolderDialog {
        id: projectDialog
        title: Translation.tr("Choose a project folder")
        onAccepted: {
            const path = FileUtils.trimFileProtocol(selectedFolder.toString());
            try { root.project = decodeURIComponent(path); }
            catch (error) { root.project = path; }
        }
    }

    component AgentButton: Button {
        id: control
        property bool emphasized: false
        implicitHeight: 34
        horizontalPadding: 11
        verticalPadding: 4
        background: Rectangle {
            radius: Appearance.rounding.windowRounding
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
            color: control.emphasized && control.enabled ? Appearance.colors.colOnLayer1
                : control.hovered && control.enabled ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
        }
        contentItem: StyledText {
            text: control.text
            font.pixelSize: Appearance.font.pixelSize.small
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: control.emphasized && control.enabled ? Appearance.colors.colLayer0
                : control.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
        }
    }

    component AgentCheck: CheckBox {
        id: control
        padding: 3
        spacing: 6
        implicitHeight: 34
        indicator: Rectangle {
            x: control.leftPadding
            y: (control.height - height) / 2
            implicitWidth: 15
            implicitHeight: 15
            radius: 4
            color: Appearance.colors.colLayer2
            border.width: 1
            border.color: control.checked ? Appearance.colors.colSubtext : Appearance.colors.colOutlineVariant
            Rectangle {
                anchors.centerIn: parent
                width: 7
                height: width
                radius: width / 2
                visible: control.checked
                color: Appearance.colors.colError
            }
        }
        contentItem: StyledText {
            leftPadding: control.indicator.width + control.spacing
            verticalAlignment: Text.AlignVCenter
            text: control.text
            font.pixelSize: Appearance.font.pixelSize.small
            color: control.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
        }
    }

    component JobText: StyledText {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        color: Appearance.colors.colOnLayer1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 9

        RowLayout {
            Layout.fillWidth: true
            spacing: 7
            StyledText {
                Layout.fillWidth: true
                text: root?.project ? root.project : Translation.tr("Desktop configs")
                elide: Text.ElideMiddle
                color: Appearance.colors.colSubtext
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
            }
            AgentButton {
                visible: Boolean(root.project)
                enabled: !root.busy
                text: Translation.tr("Desktop")
                onClicked: root.project = ""
            }
            AgentButton {
                enabled: !root.busy
                text: Translation.tr("Choose project")
                onClicked: projectDialog.open()
            }
        }

        ScrollView {
            id: output
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            clip: true

            ColumnLayout {
                width: output.availableWidth
                spacing: 8

                JobText {
                    visible: Boolean(root.job.title)
                    text: root.job.title ?? ""
                    font.family: Appearance.font.family.title
                }

                JobText {
                    text: root?.job?.stage ?? Translation.tr("Search configs, diagnose an error, or describe a change.")
                    color: ConfigAgent.active ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                JobText {
                    visible: Boolean(ConfigAgent.controlError)
                    text: ConfigAgent.controlError
                    color: Appearance.colors.colError
                }
                JobText {
                    visible: Boolean(root.job.result)
                    text: root.job.result ?? ""
                }

                Repeater {
                    model: root.job.checks ?? []
                    delegate: JobText {
                        required property string modelData
                        text: modelData
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }

                JobText {
                    visible: Boolean(root.job.visual)
                    text: root.job.visual ?? ""
                }

                RowLayout {
                    visible: Boolean(root.job.diff) || ConfigAgent.canUndo
                    Layout.fillWidth: true
                    AgentButton {
                        visible: Boolean(root.job.diff)
                        text: root?.showDiff ? Translation.tr("Hide diff") : Translation.tr("View diff")
                        onClicked: root.showDiff = !root.showDiff
                    }
                    AgentButton {
                        visible: ConfigAgent.canUndo
                        enabled: !root.busy
                        text: Translation.tr("Undo last change")
                        onClicked: ConfigAgent.undo()
                    }
                }

                TextArea {
                    visible: Boolean(root?.showDiff && root.job.diff)
                    Layout.fillWidth: true
                    text: root.job.diff ?? ""
                    textFormat: TextEdit.PlainText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Appearance.colors.colOnLayer1
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    background: Rectangle {
                        radius: Appearance.rounding.windowRounding
                        color: Appearance.colors.colLayer2
                    }
                }

                Repeater {
                    model: (root.job.events ?? []).slice(-14).reverse()
                    delegate: JobText {
                        required property var modelData
                        text: modelData.text
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }

        TextArea {
            id: taskInput
            Layout.fillWidth: true
            Layout.preferredHeight: 82
            enabled: !root.busy
            placeholderText: Translation.tr("What should the agent do?")
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            color: Appearance.colors.colOnLayer1
            placeholderTextColor: Appearance.colors.colSubtext
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.normal
            background: Rectangle {
                radius: Appearance.rounding.windowRounding
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: taskInput.activeFocus ? Appearance.colors.colSubtext : Appearance.colors.colOutlineVariant
            }
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                    root.submit();
                    event.accepted = true;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            AgentCheck {
                id: editFiles
                enabled: !root.busy
                text: Translation.tr("Edit & apply")
            }
            AgentCheck {
                id: screenAccess
                visible: !root.project
                enabled: !root.busy
                text: Translation.tr("Screen access")
            }
            Item { Layout.fillWidth: true }
            AgentButton {
                emphasized: true
                text: ConfigAgent.active ? Translation.tr("Stop") : Translation.tr("Run")
                enabled: !ConfigAgent.handlingRequest && (ConfigAgent.active || Boolean(taskInput.text.trim()))
                onClicked: ConfigAgent.active ? ConfigAgent.stop() : root.submit()
            }
        }
    }
}
