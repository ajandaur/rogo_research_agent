import Foundation

struct ToolCall: Identifiable, Equatable {
    enum State: Equatable {
        case running
        case finished(durationMs: Int)
        case failed(message: String)
    }

    /// The server's tool use id; matches finished/failed events to their row.
    let id: String
    let label: String
    var state: State = .running
}

struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user, assistant
    }

    enum Status: Equatable {
        case streaming
        case complete
        case failed(message: String)
        case cancelled
    }

    let id = UUID()
    let role: Role
    var text: String
    /// Assistant only. Rendered above the text.
    var toolCalls: [ToolCall] = []
    var status: Status
}
