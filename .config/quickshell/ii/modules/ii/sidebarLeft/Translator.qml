import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarLeft.translator
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var inputField: inputCanvas.inputTextArea
    property string translatedText: ""
    property string translationError: ""
    property list<string> languages: ["auto"]
    property string targetLanguage: Config.options.language.translator.targetLanguage
    property string sourceLanguage: Config.options.language.translator.sourceLanguage
    property bool selectTarget: false
    property bool showLanguageSelector: false
    property int revision: 0

    function showLanguageSelectorDialog(isTargetLang) {
        selectTarget = isTargetLang;
        showLanguageSelector = true;
    }

    function schedule() {
        revision++;
        translatedText = "";
        translationError = "";
        if (inputField?.text.trim()) debounce.restart();
        else debounce.stop();
    }

    onSourceLanguageChanged: schedule()
    onTargetLanguageChanged: schedule()
    onFocusChanged: if (focus) inputField?.forceActiveFocus()

    Timer {
        id: debounce
        interval: Config.options.sidebar.translator.delay
        onTriggered: {
            if (translate.running) return;
            const text = root.inputField?.text.trim();
            if (!text) return;
            if (text.length > 5000) {
                root.translationError = Translation.tr("Enter 5,000 characters or fewer.");
                return;
            }
            translate.requestRevision = root.revision;
            translate.command = ["timeout", "15s", "trans", "-brief", "-no-bidi", "-no-ansi",
                "-source", root.sourceLanguage, "-target", root.targetLanguage, "--", text];
            translate.running = true;
        }
    }

    Process {
        id: translate
        property int requestRevision: 0
        stdout: StdioCollector { id: translation }
        onExited: exitCode => {
            if (requestRevision !== root.revision) {
                if (!debounce.running && root.inputField?.text.trim()) debounce.restart();
                return;
            }
            if (exitCode !== 0 || !translation.text.trim()) {
                root.translationError = exitCode === 124 ? Translation.tr("Translation timed out.")
                    : Translation.tr("Translation failed. Check your connection and try again.");
            } else {
                root.translatedText = translation.text.trim();
            }
        }
    }

    Process {
        running: true
        command: ["timeout", "8s", "trans", "-list-languages", "-no-bidi", "-no-ansi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const codes = text.split(/\s+/).filter(code => /^[a-z]{2,3}(-[a-zA-Z]+)?$/.test(code) && code !== "auto");
                root.languages = ["auto", ...Array.from(new Set(codes)).sort()];
            }
        }
    }

    component ToolButton: Button {
        id: control
        required property string symbol
        implicitWidth: 34
        implicitHeight: 30
        background: Rectangle {
            color: control.hovered ? Appearance.colors.colLayer1Hover : "transparent"
            radius: Appearance.rounding.small
        }
        contentItem: MaterialSymbol {
            text: control.symbol
            iconSize: Appearance.font.pixelSize.large
            color: control.enabled ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: 8
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 8

            RowLayout {
                StyledText {
                    text: Translation.tr("From")
                    color: Appearance.colors.colSubtext
                }
                LanguageSelectorButton {
                    displayText: root.sourceLanguage
                    onClicked: root.showLanguageSelectorDialog(false)
                }
            }

            TextCanvas {
                id: inputCanvas
                placeholderText: Translation.tr("Enter text to translate…")
                onInputTextChanged: root.schedule()
                ToolButton {
                    symbol: "content_paste"
                    Accessible.name: Translation.tr("Paste text")
                    onClicked: root.inputField.text = Quickshell.clipboardText
                }
                ToolButton {
                    symbol: "close"
                    Accessible.name: Translation.tr("Clear translation input")
                    enabled: Boolean(root.inputField?.text)
                    onClicked: root.inputField.clear()
                }
            }

            RowLayout {
                StyledText {
                    text: Translation.tr("To")
                    color: Appearance.colors.colSubtext
                }
                LanguageSelectorButton {
                    displayText: root.targetLanguage
                    onClicked: root.showLanguageSelectorDialog(true)
                }
            }

            TextCanvas {
                id: outputCanvas
                isInput: false
                placeholderText: root.translationError || (translate.running || debounce.running
                    ? Translation.tr("Translating…") : Translation.tr("Translation appears here"))
                text: root.translatedText
                ToolButton {
                    symbol: "content_copy"
                    Accessible.name: Translation.tr("Copy translation")
                    enabled: Boolean(root.translatedText)
                    onClicked: Quickshell.clipboardText = root.translatedText
                }
                ToolButton {
                    symbol: "travel_explore"
                    Accessible.name: Translation.tr("Search for translation")
                    enabled: Boolean(root.translatedText)
                    onClicked: {
                        const terms = [root.translatedText, ...Config.options.search.excludedSites.map(site => "-site:" + site)];
                        Qt.openUrlExternally(Config.options.search.engineBaseUrl + encodeURIComponent(terms.join(" ")));
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Appearance.colors.colSubtext
                text: Translation.tr("Text is sent to Google Translate as you type.")
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.showLanguageSelector
        sourceComponent: SelectionDialog {
            titleText: root.selectTarget ? Translation.tr("Translate to") : Translation.tr("Translate from")
            items: root.selectTarget ? root.languages.filter(code => code !== "auto") : root.languages
            defaultChoice: root.selectTarget ? root.targetLanguage : root.sourceLanguage
            onCanceled: root.showLanguageSelector = false
            onSelected: result => {
                if (!result) { root.showLanguageSelector = false; return; }
                if (root.selectTarget) Config.options.language.translator.targetLanguage = result;
                else Config.options.language.translator.sourceLanguage = result;
                root.showLanguageSelector = false;
            }
        }
    }
}
