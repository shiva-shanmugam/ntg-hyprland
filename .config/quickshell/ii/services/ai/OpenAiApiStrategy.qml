import QtQuick

ApiStrategy {
    property bool isReasoning: false

    function buildRequestData(model, messages, systemPrompt, temperature, tools, thinking) {
        const data = Object.assign({}, model.extraParams, {
            model: model.model,
            messages: [{ role: "system", content: systemPrompt }, ...messages.map(message => ({
                role: message.role,
                content: message.rawContent
            }))],
            stream: true,
            temperature
        });
        delete data.tools;
        delete data.tool_choice;
        return data;
    }

    function appendContent(message, content, reasoning) {
        if (reasoning) {
            if (!isReasoning) {
                isReasoning = true;
                message.content += "\n\n<think>\n\n";
            }
            message.content += reasoning;
        }
        if (content) {
            closeReasoning(message);
            message.rawContent += content;
            message.content += content;
        }
    }

    function closeReasoning(message) {
        if (isReasoning) {
            isReasoning = false;
            message.content += "\n\n</think>\n\n";
        }
    }

    function parseResponseLine(line, message) {
        const data = line.startsWith("data:") ? line.slice(5).trim() : line.trim();
        if (!data || data.startsWith(":")) return {};
        if (data === "[DONE]") return { finished: true };
        const response = JSON.parse(data);
        if (response.error) return { error: response.error.message ?? String(response.error) };
        const choice = response.choices?.[0];
        const delta = choice?.delta ?? choice?.message;
        appendContent(message, delta?.content, delta?.reasoning ?? delta?.reasoning_content);
        return {
            finished: Boolean(choice?.finish_reason),
            tokenUsage: response.usage ? {
                input: response.usage.prompt_tokens ?? -1,
                output: response.usage.completion_tokens ?? -1,
                total: response.usage.total_tokens ?? -1
            } : null
        };
    }

    function finish(message) {
        closeReasoning(message);
    }

    function reset() {
        isReasoning = false;
    }
}
