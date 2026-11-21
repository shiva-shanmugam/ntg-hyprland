import QtQuick

QtObject {
    function buildRequestData(model, messages, systemPrompt, temperature, tools, thinking) {
        throw new Error("Missing model adapter")
    }
    function parseResponseLine(line, message) {
        throw new Error("Missing response parser")
    }
    function finish(message) {}
    function reset() {}
}
