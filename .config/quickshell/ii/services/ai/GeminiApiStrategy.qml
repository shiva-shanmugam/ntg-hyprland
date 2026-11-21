import QtQuick

ApiStrategy {
    function buildRequestData(model, messages, systemPrompt, temperature, tools, thinking) {
        return Object.assign({}, model.extraParams, {
            contents: messages.map(message => ({
                role: message.role === "assistant" ? "model" : "user",
                parts: [{ text: message.rawContent }]
            })),
            tools,
            system_instruction: { parts: [{ text: systemPrompt }] },
            generationConfig: { temperature }
        });
    }

    function parseResponseLine(line, message) {
        const data = line.startsWith("data:") ? line.slice(5).trim() : line.trim();
        if (!data || data.startsWith(":")) return {};
        const result = JSON.parse(data);
        if (result.error) return { error: result.error.message };
        const candidate = result.candidates?.[0];
        for (const part of candidate?.content?.parts ?? []) {
            if (part.text && !part.thought) {
                message.rawContent += part.text;
                message.content += part.text;
            }
        }
        const grounding = candidate?.groundingMetadata;
        if (grounding) {
            const sources = grounding.groundingChunks ?? [];
            message.annotationSources = sources.map(source => ({
                title: source.web?.title ?? "",
                url: source.web?.uri ?? ""
            })).filter(source => source.url);
            message.searchQueries = grounding.webSearchQueries ?? [];
        }
        return {
            finished: Boolean(candidate?.finishReason),
            tokenUsage: result.usageMetadata ? {
                input: result.usageMetadata.promptTokenCount ?? -1,
                output: result.usageMetadata.candidatesTokenCount ?? -1,
                total: result.usageMetadata.totalTokenCount ?? -1
            } : null
        };
    }
}
