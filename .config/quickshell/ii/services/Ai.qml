pragma Singleton

import qs
import qs.modules.common
import qs.modules.common.functions as CF
import qs.services.ai
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string interfaceRole: "interface"
    readonly property string backend: CF.FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/ai/assistant-backend.py"))
    readonly property bool localOnly: Config.options.policies.ai === 2
    readonly property bool busy: requester.inFlight
    readonly property bool awaitingApproval: pendingAction !== null
    readonly property bool discovering: modelDiscovery.running
    readonly property bool supportsImages: getModel()?.capabilities.includes("vision") ?? false
    readonly property bool supportsThinking: Boolean(getModel()?.capabilities.includes("thinking")) && !getModel()?.fixedReasoning
    readonly property bool currentModelHasApiKey: !getModel()?.requires_key || Boolean(apiKeys[getModel()?.key_id])
    readonly property var apiKeys: KeyringStorage.keyringData?.apiKeys ?? {}
    readonly property var availableTools: {
        const model = getModel();
        if (model?.api_format === "ollama" && model.capabilities.includes("tools")) return ["none", "functions"];
        if (model?.api_format === "gemini" && model.model.startsWith("gemini-")) return ["none", "search"];
        return ["none"];
    }
    readonly property string currentTool: availableTools.includes(Config.options.ai.tool) ? Config.options.ai.tool : "none"
    readonly property var toolDescriptions: ({
        none: Translation.tr("Chat without tools"),
        functions: Translation.tr("Read selected desktop settings and propose changes for approval"),
        search: Translation.tr("Search the web with the selected Gemini model")
    })
    readonly property var desktopSettings: ({
        "bar.showBackground": Translation.tr("Bar background"),
        "bar.bottom": Translation.tr("Bar position"),
        "bar.weather.enable": Translation.tr("Bar weather"),
        "sidebar.translator.enable": Translation.tr("Translator tab")
    })

    property var messageIDs: []
    property var messageByID: ({})
    property var pendingAction: null
    property string pendingFilePath: ""
    property real temperature: Number.isFinite(Persistent.states.ai.temperature) ? Persistent.states.ai.temperature : 0.5
    property bool thinkingEnabled: Persistent.states.ai.thinkingEnabled
    property list<string> promptFiles: []
    property list<string> savedChats: []
    property string statusError: ""
    property QtObject tokenCount: QtObject {
        property int input: -1
        property int output: -1
        property int total: -1
    }
    signal responseFinished()

    Component { id: messageComponent; AiMessageData {} }
    Component { id: modelComponent; AiModel {} }
    OpenAiApiStrategy { id: openai }
    OllamaApiStrategy { id: ollama }
    GeminiApiStrategy { id: gemini }
    MistralApiStrategy { id: mistral }

    readonly property var strategies: ({ openai, ollama, gemini, mistral })
    property var discoveredModels: ({})
    property var configuredModels: ({})
    property var builtinModels: {
        "gemini-2.5-flash": modelComponent.createObject(this, {
            "name": "Gemini 2.5 Flash",
            "icon": "google-gemini-symbolic",
            "description": Translation.tr("Online | Google's model\nNewer model that's slower than its predecessor but should deliver higher quality answers"),
            "homepage": "https://aistudio.google.com",
            "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent",
            "model": "gemini-2.5-flash",
            "requires_key": true,
            "key_id": "gemini",
            "key_get_link": "https://aistudio.google.com/app/apikey",
            "key_get_description": Translation.tr("**Pricing**: free. Data used for training.\n\n**Instructions**: Log into Google account, allow AI Studio to create Google Cloud project or whatever it asks, go back and click Get API key"),
            "api_format": "gemini",
        }),
        "gemini-3-flash": modelComponent.createObject(this, {
            "name": "Gemini 3 Flash",
            "icon": "google-gemini-symbolic",
            "description": Translation.tr("Online | Google's model\nPro-level intelligence at the speed and pricing of Flash."),
            "homepage": "https://aistudio.google.com",
            "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:streamGenerateContent",
            "model": "gemini-3-flash-preview",
            "requires_key": true,
            "key_id": "gemini",
            "key_get_link": "https://aistudio.google.com/app/apikey",
            "key_get_description": Translation.tr("**Pricing**: free. Data used for training.\n\n**Instructions**: Log into Google account, allow AI Studio to create Google Cloud project or whatever it asks, go back and click Get API key"),
            "api_format": "gemini",
        }),
	"gemma-4-26b-a4b-it": modelComponent.createObject(this, {
            "name": "Gemma 4 26B A4B IT",
            "icon": "google-gemini-symbolic",
            "description": Translation.tr("Online | Google's open weights model\nInstruction-tuned 26-billion parameter model balancing high quality with open portability"),
            "homepage": "https://aistudio.google.com",
            "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemma-4-26b-a4b-it:streamGenerateContent",
            "model": "gemma-4-26b-a4b-it",
            "requires_key": true,
            "key_id": "gemini",
            "key_get_link": "https://aistudio.google.com/app/apikey",
            "key_get_description": Translation.tr("**Pricing**: free. Data used for training.\n\n**Instructions**: Log into Google account, allow AI Studio to create Google Cloud project or whatever it asks, go back and click Get API key"),
            "api_format": "gemini",
        }),
	"gemma-4-31b-it": modelComponent.createObject(this, {
            "name": "Gemma 4 31B IT",
            "icon": "google-gemini-symbolic",
            "description": Translation.tr("Online | Google's open weights model\nInstruction-tuned 31-billion parameter model balancing high quality with open portability"),
            "homepage": "https://aistudio.google.com",
            "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemma-4-31b-it:streamGenerateContent",
            "model": "gemma-4-31b-it",
            "requires_key": true,
            "key_id": "gemini",
            "key_get_link": "https://aistudio.google.com/app/apikey",
            "key_get_description": Translation.tr("**Pricing**: free. Data used for training.\n\n**Instructions**: Log into Google account, allow AI Studio to create Google Cloud project or whatever it asks, go back and click Get API key"),
            "api_format": "gemini",
        }),
        "mistral-medium-3": modelComponent.createObject(this, {
            "name": "Mistral Medium 3",
            "icon": "mistral-symbolic",
            "description": Translation.tr("Online | %1's model | Delivers fast, responsive and well-formatted answers. Disadvantages: not very eager to do stuff; might make up unknown function calls").arg("Mistral"),
            "homepage": "https://mistral.ai/news/mistral-medium-3",
            "endpoint": "https://api.mistral.ai/v1/chat/completions",
            "model": "mistral-medium-2505",
            "requires_key": true,
            "key_id": "mistral",
            "key_get_link": "https://console.mistral.ai/api-keys",
            "key_get_description": Translation.tr("**Instructions**: Log into Mistral account, go to Keys on the sidebar, click Create new key"),
            "api_format": "mistral",
        }),
    }
    readonly property var models: {
        if (!Config.ready || Config.options.policies.ai === 0) return {};
        const candidates = Object.assign({}, localOnly ? {} : builtinModels, configuredModels, discoveredModels);
        const available = {};
        for (const [id, model] of Object.entries(candidates)) {
            if (strategies[model?.api_format] && (!localOnly || (isLocal(model.endpoint) && !/[-:]cloud$/i.test(model.model))))
                available[id] = model;
        }
        return available;
    }

    readonly property list<string> modelList: Object.keys(models)
    readonly property string currentModelId: {
        const preferred = Persistent.states.ai.model;
        if (models[preferred]) return preferred;
        if (models.qwen3_8b) return "qwen3_8b";
        return modelList.find(id => isLocal(models[id].endpoint)) ?? modelList[0] ?? "";
    }

    function isLocal(endpoint) {
        return /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?(\/|$)/i.test(endpoint);
    }

    function modelId(name) {
        return name.replace(/:/g, "_").replace(/ /g, "-").replace(/\//g, "-").toLowerCase();
    }

    function configureModels() {
        const previous = configuredModels;
        const entries = {};
        for (const options of Config.options.ai.extraModels) {
            if (!options.model || !options.endpoint) continue;
            if (localOnly && !isLocal(options.endpoint)) continue;
            entries[modelId(options.model)] = modelComponent.createObject(root, options);
        }
        configuredModels = entries;
        for (const model of Object.values(previous)) model?.destroy();
    }

    Component.onCompleted: {
        if (Config.ready) configureModels();
        refreshModels();
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) root.configureModels();
        }
    }

    onLocalOnlyChanged: if (Config.ready) {
        if (localOnly && (busy || awaitingApproval)) stop();
        configureModels();
    }

    function getModel() {
        return models[currentModelId] ?? null;
    }

    function refreshModels() {
        modelDiscovery.running = true;
    }

    Process {
        id: modelDiscovery
        command: ["python3", root.backend, "discover"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                try {
                    const previous = root.discoveredModels;
                    const entries = {};
                    for (const item of JSON.parse(text)) {
                        const name = item.model;
                        const label = name.replace("qwen3", "Qwen3").replace("gemma4", "Gemma 4")
                            .replace("llama3.1", "Llama 3.1").replace(":4b", " (4B)")
                            .replace(":8b", " (8B)").replace(":e4b", " (E4B)");
                        entries[root.modelId(name)] = modelComponent.createObject(root, {
                            model: name, name: label, icon: "ollama-symbolic",
                            description: item.fixedReasoning ? Translation.tr("Local Ollama · reasoning always on")
                                : Translation.tr("Local Ollama · %1").arg(item.capabilities.join(", ")),
                            endpoint: "http://127.0.0.1:11434/api/chat", api_format: "ollama",
                            requires_key: false, capabilities: item.capabilities, fixedReasoning: item.fixedReasoning,
                            extraParams: name === "gemma4:e4b" ? { options: { num_gpu: 0, num_ctx: 2048 } } : {}
                        });
                    }
                    root.discoveredModels = entries;
                    for (const model of Object.values(previous)) model?.destroy();
                } catch (error) {
                    root.statusError = Translation.tr("Could not read the Ollama model list.");
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && !root.getModel())
                root.statusError = Translation.tr("Ollama is unavailable. Start it and refresh models.");
        }
    }

    Process {
        running: true
        command: ["find", CF.FileUtils.trimFileProtocol(Directories.defaultAiPrompts),
            Directories.userAiPrompts, "-maxdepth", "1", "-type", "f"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.promptFiles = text.trim().split("\n").filter(path =>
                    /\.(md|txt)$/i.test(path) && !/\/(ii-Imouto|nyarch-Acchan)\.md$/.test(path)
                );
            }
        }
    }

    FileView {
        id: promptLoader
        blockLoading: true
        onLoaded: Config.options.ai.systemPrompt = text()
        onLoadFailed: root.notice(Translation.tr("Unable to load the preset."))
    }

    function loadPrompt(path) {
        if (!promptFiles.includes(path)) {
            notice(Translation.tr("Choose a preset from the prompt list."));
            return;
        }
        promptLoader.path = path;
        promptLoader.reload();
    }

    function printPrompt() {
        notice(Config.options.ai.systemPrompt);
    }

    function addMessage(content, role, extra = {}) {
        if (!content && role !== "assistant") return null;
        const message = messageComponent.createObject(root, Object.assign({
            role, content, rawContent: content, thinking: false, done: true
        }, extra));
        const id = Date.now().toString(36) + Math.random().toString(36).slice(2);
        // Write the object lookup before notifying the view of the new ID.
        messageByID = Object.assign({}, messageByID, { [id]: message });
        messageIDs = [...messageIDs, id];
        return message;
    }

    function notice(text) {
        addMessage(text, interfaceRole);
    }

    function removeMessage(index) {
        if (busy || awaitingApproval || index < 0 || index >= messageIDs.length) return;
        const id = messageIDs[index];
        const message = messageByID[id];
        messageIDs = messageIDs.filter(other => other !== id);
        const entries = Object.assign({}, messageByID);
        delete entries[id];
        messageByID = entries;
        message?.destroy();
    }

    function setModel(id) {
        if (busy || awaitingApproval) {
            notice(Translation.tr("Finish the current turn before switching models."));
            return false;
        }
        const key = modelId(id ?? "");
        if (!models[key]) {
            notice(Translation.tr("Available models: %1").arg(modelList.join(", ") || Translation.tr("none")));
            return false;
        }
        if (!isLocal(models[key].endpoint) && messageIDs.some(id => messageByID[id].role === "user")) {
            notice(Translation.tr("Start a new chat before switching to an online model."));
            return false;
        }
        Persistent.states.ai.model = key;
        statusError = "";
        if (models[key].requires_key && !KeyringStorage.loaded) KeyringStorage.fetchKeyringData();
        return true;
    }

    function setTool(tool) {
        if (busy || awaitingApproval) return false;
        if (!availableTools.includes(tool)) {
            notice(Translation.tr("Tools for this model: %1").arg(availableTools.join(", ")));
            return false;
        }
        Config.options.ai.tool = tool;
        return true;
    }

    function setTemperature(value) {
        const maximum = getModel()?.api_format === "gemini" ? 2 : 1;
        if (!Number.isFinite(value) || value < 0 || value > maximum) {
            notice(Translation.tr("Enter a number between 0 and %1.").arg(maximum));
            return;
        }
        Persistent.states.ai.temperature = value;
        printTemperature();
    }

    function printTemperature() {
        notice(Translation.tr("Temperature: %1").arg(temperature));
    }

    function setThinking(arg) {
        if (!supportsThinking) {
            notice(Translation.tr("This model has no reasoning switch."));
            return;
        }
        const answer = arg?.toLowerCase() ?? "";
        if (answer && !["on", "off", "yes", "no", "true", "false", "1", "0"].includes(answer)) {
            notice(Translation.tr("Use /think on or /think off."));
            return;
        }
        Persistent.states.ai.thinkingEnabled = answer ? ["on", "yes", "true", "1"].includes(answer) : !thinkingEnabled;
        notice(thinkingEnabled ? Translation.tr("Reasoning is on.") : Translation.tr("Reasoning is off."));
    }

    function setApiKey(key) {
        const model = getModel();
        if (!model?.requires_key) {
            notice(Translation.tr("This model does not require an API key."));
            return;
        }
        if (!key?.trim()) {
            printApiKey();
            return;
        }
        KeyringStorage.setNestedField(["apiKeys", model.key_id], key.trim());
        notice(Translation.tr("API key stored in the keyring."));
    }

    function printApiKey() {
        if (!getModel()?.requires_key) notice(Translation.tr("This model does not require an API key."));
        else notice(currentModelHasApiKey ? Translation.tr("An API key is stored.") : Translation.tr("No key is stored. Use /key followed by the key."));
    }

    function setHistory(action) {
        if (action === "on" || action === "off") {
            Config.options.ai.autoSave = action === "on";
        } else if (action && action !== "get") {
            notice(Translation.tr("Use /history on or /history off."));
            return;
        }
        notice(Config.options.ai.autoSave ? Translation.tr("Automatic history is on. Use /load lastSession to reopen it.")
            : Translation.tr("Automatic history is off. Use /save NAME to keep this chat."));
    }

    function abort(discard) {
        if (busy) {
            requester.interrupted = true;
            requester.discard = discard;
            if (!discard && requester.message) {
                requester.message.done = true;
                requester.message.failed = true;
            }
            requester.running = false;
        }
        if (pendingAction) {
            pendingAction.functionPending = false;
            pendingAction = null;
        }
    }

    function stop() {
        abort(false);
    }

    function clearMessages() {
        abort(true);
        const previous = messageByID;
        messageIDs = [];
        messageByID = ({});
        for (const message of Object.values(previous)) message.destroy();
        pendingFilePath = "";
        statusError = "";
        tokenCount.input = tokenCount.output = tokenCount.total = -1;
    }

    function canRequest() {
        if (busy || awaitingApproval || historyProcess.operation === "load") return false;
        const model = getModel();
        if (!model) {
            statusError = Translation.tr("No model available. Start Ollama and use /models to refresh.");
            return false;
        }
        if (model.requires_key && !currentModelHasApiKey) {
            if (!KeyringStorage.loaded) KeyringStorage.fetchKeyringData();
            statusError = Translation.tr("The model needs an API key. Use /key to check or set it.");
            return false;
        }
        return true;
    }

    function sendUserMessage(text) {
        if ((!text.trim() && !pendingFilePath) || !canRequest()) return false;
        addMessage(text.trim() ? text : Translation.tr("Describe the attachment."), "user", {
            localFilePath: pendingFilePath
        });
        pendingFilePath = "";
        request();
        return true;
    }

    function attachFile(filePath) {
        if (busy || awaitingApproval) return false;
        let path = CF.FileUtils.trimFileProtocol(filePath);
        if (filePath.startsWith("file:")) {
            try { path = decodeURIComponent(path); } catch (error) {}
        }
        pendingFilePath = path;
        return true;
    }

    function regenerate(index) {
        if (!canRequest() || index < 0 || index >= messageIDs.length) return;
        const message = messageByID[messageIDs[index]];
        if (message?.role !== "assistant") return;
        for (let i = messageIDs.length - 1; i >= index; i--) removeMessage(i);
        request();
    }

    function request() {
        const model = getModel();
        const strategy = strategies[model.api_format];
        const sentTools = currentTool;
        strategy.reset();
        const messages = messageIDs.map(id => messageByID[id]).filter(message =>
            message && message.role !== interfaceRole && !message.failed
            && (model.api_format === "ollama" || message.role !== "tool")
        );
        const attachments = [];
        messages.forEach((message, index) => {
            if (message.localFilePath && message.role === "user") attachments.push({ index, path: message.localFilePath });
        });
        const prompt = Config.options.ai.systemPrompt.split("\n")
            .filter(line => !line.includes("{DATETIME}") && !line.includes("{WINDOWCLASS}"))
            .join("\n").replace("{DISTRO}", SystemInfo.distroName).replace("{DE}", SystemInfo.desktopEnvironment);
        const maxTemperature = model.api_format === "gemini" ? 2 : 1;
        const data = strategy.buildRequestData(model, messages, prompt, Math.min(temperature, maxTemperature),
            toolsFor(sentTools), thinkingEnabled);
        const packet = {
            endpoint: model.endpoint, provider: model.api_format, localOnly, data, attachments,
            images: supportsImages || model.api_format === "gemini"
        };

        statusError = "";
        tokenCount.input = tokenCount.output = tokenCount.total = -1;
        requester.strategy = strategy;
        requester.mode = sentTools;
        requester.interrupted = false;
        requester.discard = false;
        requester.finished = false;
        requester.failure = "";
        requester.calls = [];
        requester.message = addMessage("", "assistant", { model: currentModelId, done: false });
        requester.payload = JSON.stringify(packet);
        requester.environment = { ASSISTANT_API_KEY: model.requires_key ? (apiKeys[model.key_id] ?? "") : "" };
        requester.stdinEnabled = true;
        requester.inFlight = true;
        requester.running = true;
        requestTimer.restart();
    }

    Timer {
        id: requestTimer
        interval: 120000
        onTriggered: {
            requester.failure = Translation.tr("The model took too long to reply.");
            requester.running = false;
        }
    }

    Process {
        id: requester
        command: ["python3", root.backend, "request"]
        property bool inFlight: false
        property var message: null
        property var strategy
        property string payload
        property string mode
        property string failure
        property var calls: []
        property bool finished: false
        property bool interrupted: false
        property bool discard: false

        onStarted: {
            write(payload);
            stdinEnabled = false;
            payload = "";
        }

        stdout: SplitParser {
            onRead: line => {
                if (!line.trim() || requester.interrupted || requester.failure) return;
                try {
                    const result = requester.strategy.parseResponseLine(line, requester.message);
                    if (result.error) requester.failure = result.error;
                    if (result.calls?.length) requester.calls = result.calls;
                    if (result.finished) requester.finished = true;
                    const count = result.tokenUsage;
                    if (count) {
                        root.tokenCount.input = count.input;
                        root.tokenCount.output = count.output;
                        root.tokenCount.total = count.total;
                    }
                } catch (error) {
                    requester.failure = Translation.tr("The model returned an invalid response.");
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (!requester.failure && text.trim()) requester.failure = text.trim().slice(0, 500);
            }
        }

        onExited: exitCode => {
            requestTimer.stop();
            inFlight = false;
            const reply = message;
            message = null;
            if (discard || !reply) return;
            reply.done = true;
            strategy.finish(reply);
            if (interrupted) {
                reply.failed = true;
                reply.content += "\n\n" + Translation.tr("Stopped.");
            } else if (failure || exitCode !== 0 || !finished || (!reply.rawContent.trim() && !calls.length)) {
                reply.failed = true;
                const reason = failure || Translation.tr("The model closed the connection before completing a reply.");
                reply.content += "\n\n" + Translation.tr("Request failed: %1").arg(reason);
                root.statusError = reason;
            } else if (calls.length) {
                root.proposeAction(mode, calls, reply);
            }
            if (Config.options.ai.autoSave && !root.awaitingApproval && !reply.failed)
                root.saveChat("lastSession", false);
            root.responseFinished();
        }
    }

    function toolsFor(mode) {
        if (mode === "search") return [{ google_search: {} }];
        if (mode !== "functions") return [];
        return [
            { type: "function", function: {
                name: "get_shell_config", description: "Read the current values of the supported desktop settings.",
                parameters: { type: "object", properties: {}, additionalProperties: false }
            }},
            { type: "function", function: {
                name: "set_shell_config", description: "Propose a desktop setting change for the user to approve.",
                parameters: { type: "object", properties: {
                    key: { type: "string", enum: Object.keys(desktopSettings) },
                    value: { type: "boolean" }
                }, required: ["key", "value"], additionalProperties: false }
            }}
        ];
    }

    function currentSetting(key) {
        return key.split(".").reduce((parent, name) => parent?.[name], Config.options);
    }

    function proposeAction(mode, calls, reply) {
        const action = calls[0]?.function;
        if (mode !== "functions" || currentTool !== "functions" || calls.length !== 1 || !action) {
            reply.content += "\n\n" + Translation.tr("The model requested an unavailable action.");
            reply.failed = true;
            return;
        }
        const args = action.arguments;
        if (action.name === "get_shell_config") {
            const values = {};
            for (const key of Object.keys(desktopSettings)) values[key] = currentSetting(key);
            reply.functionName = action.name;
            reply.functionCall = { args: {} };
            reply.content += "\n\n```json\n" + JSON.stringify(values, null, 2) + "\n```";
            addMessage(JSON.stringify(values), "tool", { functionName: action.name, visibleToUser: false });
        } else if (action.name === "set_shell_config" && typeof args?.value === "boolean"
            && typeof args.key === "string" && Object.keys(desktopSettings).includes(args.key)) {
            const before = currentSetting(args.key);
            reply.functionName = action.name;
            reply.functionCall = { args };
            reply.functionPending = true;
            pendingAction = reply;
            reply.content += "\n\n**Desktop setting request**\n\n" + desktopSettings[args.key]
                + "\n\n```configdiff\n- " + before + "\n+ " + args.value + "\n```";
        } else {
            reply.content += "\n\n" + Translation.tr("The model requested an unsupported setting or value.");
            reply.failed = true;
        }
    }

    function decide(message, approve) {
        if (message !== pendingAction || !message?.functionPending) return;
        const args = message.functionCall.args;
        const allowed = currentTool === "functions" && Object.keys(desktopSettings).includes(args.key)
            && typeof args.value === "boolean";
        if (approve && allowed) Config.setNestedValue(args.key, args.value);
        const outcome = approve && allowed ? Translation.tr("Desktop setting updated.") : Translation.tr("Desktop setting declined.");
        message.functionPending = false;
        pendingAction = null;
        addMessage(outcome, "tool", { functionName: message.functionName, visibleToUser: false });
        notice(outcome);
        if (Config.options.ai.autoSave) saveChat("lastSession", false);
    }

    function rejectCommand(message) { decide(message, false); }
    function approveCommand(message) { decide(message, true); }

    function saveChat(name, feedback = true) {
        if (historyProcess.running || (feedback && (busy || awaitingApproval))) return;
        const saved = messageIDs.map(id => messageByID[id]).filter(message =>
            message && ["user", "assistant"].includes(message.role) && !message.failed
        ).map(message => ({
            role: message.role, rawContent: message.rawContent, model: message.model
        }));
        historyProcess.perform("save", name, JSON.stringify(saved), feedback);
    }

    function loadChat(name) {
        if (busy || awaitingApproval || historyProcess.running) {
            notice(Translation.tr("Finish the current turn before loading a chat."));
            return;
        }
        historyProcess.perform("load", name, "", true);
    }

    Timer {
        running: true
        interval: 100
        onTriggered: if (!historyProcess.running) historyProcess.perform("list", "", "", false)
    }

    Process {
        id: historyProcess
        property string operation
        property string name
        property string input
        property bool feedback

        function perform(op, chatName, data, showMessage) {
            operation = op;
            name = chatName.trim();
            input = data;
            feedback = showMessage;
            stdinEnabled = op === "save";
            command = ["python3", root.backend, "history", operation, Directories.aiChats, name];
            running = true;
        }

        onStarted: if (operation === "save") {
            write(input);
            stdinEnabled = false;
            input = "";
        }

        stdout: StdioCollector { id: historyOutput }
        stderr: StdioCollector { id: historyErrors }

        onExited: exitCode => {
            const op = operation;
            operation = "";
            if (exitCode !== 0) {
                root.notice(op === "load" ? Translation.tr("Could not load chat: %1").arg(name)
                    : Translation.tr("Could not update history: %1").arg(historyErrors.text.trim()));
                return;
            }
            if (op === "save") {
                root.savedChats = Array.from(new Set([...root.savedChats, name])).sort();
                if (feedback) root.notice(Translation.tr("Saved %1.").arg(name));
            } else if (op === "list") {
                root.savedChats = JSON.parse(historyOutput.text);
            } else {
                const data = JSON.parse(historyOutput.text);
                root.clearMessages();
                for (const item of data) {
                    if (["user", "assistant"].includes(item?.role) && typeof item.rawContent === "string")
                        root.addMessage(item.rawContent, item.role, { model: typeof item.model === "string" ? item.model : "" });
                }
            }
        }
    }
}
