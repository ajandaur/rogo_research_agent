import Foundation

/// A typed event from the agent's SSE stream. See CLAUDE.md for the wire schema.
enum AgentEvent: Equatable, Sendable {
    case toolStarted(id: String, label: String)
    case toolFinished(id: String, durationMs: Int)
    case toolFailed(id: String, message: String)
    case textDelta(String)
    case done
    case error(message: String)

    /// `done` and `error` end the stream.
    var isTerminal: Bool {
        switch self {
        case .done, .error: true
        default: false
        }
    }

    /// Decodes an SSE frame. Returns nil for event types this app doesn't know,
    /// so the server can add events without breaking older clients.
    init?(_ sse: SSEEvent) throws {
        let data = Data(sse.data.utf8)
        let decoder = JSONDecoder()

        switch sse.event {
        case "tool_started":
            let payload = try decoder.decode(ToolStarted.self, from: data)
            self = .toolStarted(id: payload.toolUseId, label: payload.label)
        case "tool_finished":
            let payload = try decoder.decode(ToolFinished.self, from: data)
            self = .toolFinished(id: payload.toolUseId, durationMs: payload.durationMs)
        case "tool_failed":
            let payload = try decoder.decode(ToolFailed.self, from: data)
            self = .toolFailed(id: payload.toolUseId, message: payload.message)
        case "text_delta":
            self = .textDelta(try decoder.decode(TextDelta.self, from: data).text)
        case "done":
            self = .done
        case "error":
            self = .error(message: try decoder.decode(ErrorPayload.self, from: data).message)
        default:
            return nil
        }
    }
}

private struct ToolStarted: Decodable {
    let toolUseId: String
    let label: String
}

private struct ToolFinished: Decodable {
    let toolUseId: String
    let durationMs: Int
}

private struct ToolFailed: Decodable {
    let toolUseId: String
    let message: String
}

private struct TextDelta: Decodable {
    let text: String
}

private struct ErrorPayload: Decodable {
    let message: String
}
