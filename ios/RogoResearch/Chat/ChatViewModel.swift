import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    enum RunState: Equatable {
        case idle
        case streaming
        case failed(message: String)
    }

    private(set) var messages: [ChatMessage] = []
    private(set) var runState: RunState = .idle
    var draft = ""

    private let service: any AgentServicing
    private var runTask: Task<Void, Never>?

    init(service: any AgentServicing) {
        self.service = service
    }

    var canSend: Bool {
        runState != .streaming && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func send() {
        guard canSend else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        messages.append(ChatMessage(role: .user, text: text, status: .complete))
        startRun()
    }

    /// Stops the current answer. Cancelling the task closes the connection,
    /// which cancels the run on the server.
    func cancel() {
        guard runState == .streaming else { return }
        runTask?.cancel()
        runTask = nil
        if let index = messages.indices.last, messages[index].status == .streaming {
            messages[index].status = .cancelled
        }
        runState = .idle
    }

    /// True when the last reply failed or was stopped, and nothing is running.
    var canRetry: Bool {
        guard runState != .streaming, let last = messages.last, last.role == .assistant else {
            return false
        }
        switch last.status {
        case .failed, .cancelled: return true
        case .streaming, .complete: return false
        }
    }

    /// Replaces a failed or stopped reply by asking the same question again.
    func retry() {
        guard canRetry else { return }
        messages.removeLast()
        startRun()
    }

    func newConversation() {
        runTask?.cancel()
        runTask = nil
        messages = []
        draft = ""
        runState = .idle
    }

    /// Waits for the current run's task to end. For tests.
    func waitForRun() async {
        await runTask?.value
    }

    // MARK: - Running

    private func startRun() {
        let history = wireHistory()
        let reply = ChatMessage(role: .assistant, text: "", status: .streaming)
        let replyID = reply.id
        messages.append(reply)
        runState = .streaming

        // Start the request now, in send order, rather than whenever the task first
        // runs. If the task is cancelled, ending its iteration closes the stream,
        // and the service's onTermination cancels the request.
        let events = service.stream(messages: history)

        // The task inherits the main actor, so it can update state directly.
        runTask = Task {
            do {
                for try await event in events {
                    // A cancelled run may still have events in flight: drop them.
                    // Without this they would land after cancel() or newConversation().
                    guard !Task.isCancelled else { return }
                    apply(event, to: replyID)
                }
                guard !Task.isCancelled else { return }
                // The service always ends on done/error or throws; this is a backstop.
                if runState == .streaming {
                    fail(replyID, message: AgentServiceError.streamEndedEarly.localizedDescription)
                }
            } catch {
                guard !Task.isCancelled else { return }
                fail(replyID, message: error.localizedDescription)
            }
        }
    }

    private func apply(_ event: AgentEvent, to messageID: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }

        switch event {
        case .toolStarted(let id, let label):
            messages[index].toolCalls.append(ToolCall(id: id, label: label))
        case .toolFinished(let id, let durationMs):
            updateTool(id, in: index, to: .finished(durationMs: durationMs))
        case .toolFailed(let id, let message):
            updateTool(id, in: index, to: .failed(message: message))
        case .textDelta(let text):
            messages[index].text += text
        case .done:
            messages[index].status = .complete
            runState = .idle
            runTask = nil
        case .error(let message):
            fail(messageID, message: message)
        }
    }

    private func updateTool(_ id: String, in index: Int, to state: ToolCall.State) {
        guard let toolIndex = messages[index].toolCalls.firstIndex(where: { $0.id == id }) else {
            return
        }
        messages[index].toolCalls[toolIndex].state = state
    }

    private func fail(_ messageID: UUID, message: String) {
        if let index = messages.firstIndex(where: { $0.id == messageID }) {
            messages[index].status = .failed(message: message)
        }
        runState = .failed(message: message)
        runTask = nil
    }

    /// Completed question/answer pairs plus the trailing question. Failed or
    /// cancelled turns are left out so the history stays user/assistant alternating.
    private func wireHistory() -> [WireMessage] {
        var history: [WireMessage] = []
        var index = messages.startIndex
        while index < messages.endIndex {
            let message = messages[index]
            guard message.role == .user else {
                index += 1
                continue
            }
            let next = index + 1 < messages.endIndex ? messages[index + 1] : nil
            if let next, next.role == .assistant {
                if next.status == .complete {
                    history.append(WireMessage(role: .user, content: message.text))
                    history.append(WireMessage(role: .assistant, content: next.text))
                }
                index += 2
            } else {
                // The question being asked now.
                history.append(WireMessage(role: .user, content: message.text))
                index += 1
            }
        }
        return history
    }
}
