import QtQuick

OpenAiApiStrategy {
    property var calls: []

    function buildRequestData(model, messages, systemPrompt, temperature, tools, thinking) {
        const extra = model.extraParams ?? {};
        const options = Object.assign({}, extra.options, { temperature });
        const data = Object.assign({}, extra, {
            model: model.model,
            messages: [{ role: "system", content: systemPrompt }, ...messages.map(message => {
                const item = { role: message.role, content: message.rawContent };
                if (message.functionCall && message.functionName) {
                    item.tool_calls = [{ function: { name: message.functionName, arguments: message.functionCall.args } }];
                }
                if (message.role === "tool") item.tool_name = message.functionName;
                return item;
            })],
            stream: true,
            tools,
            options
        });
        if (model.capabilities.includes("thinking")) data.think = model.fixedReasoning || thinking;
        return data;
    }

    function parseResponseLine(line, message) {
        const response = JSON.parse(line);
        if (response.error) return { error: String(response.error) };
        const delta = response.message;
        appendContent(message, delta?.content, delta?.thinking);
        if (Array.isArray(delta?.tool_calls)) calls = [...calls, ...delta.tool_calls];
        return {
            finished: response.done === true,
            calls: response.done ? calls : [],
            tokenUsage: response.done ? {
                input: response.prompt_eval_count ?? -1,
                output: response.eval_count ?? -1,
                total: (response.prompt_eval_count ?? 0) + (response.eval_count ?? 0)
            } : null
        };
    }

    function reset() {
        isReasoning = false;
        calls = [];
    }
}
