import Foundation

/// One turn of conversation history, as the server expects it.
struct WireMessage: Encodable, Equatable, Sendable {
    enum Role: String, Encodable, Sendable {
        case user, assistant
    }

    let role: Role
    let content: String
}

enum AgentServiceError: LocalizedError, Equatable {
    case badStatus(Int)
    case streamEndedEarly

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): "The server returned an error (\(code))."
        case .streamEndedEarly: "The connection closed before the answer finished."
        }
    }
}

protocol AgentServicing: Sendable {
    /// Starts a run and streams its events. The stream finishes after `done` or
    /// `error`. Cancelling the consuming task closes the connection, which
    /// cancels the run on the server.
    func stream(messages: [WireMessage]) -> AsyncThrowingStream<AgentEvent, Error>
}

struct URLSessionAgentService: AgentServicing {
    let baseURL: URL
    var session: URLSession = .shared

    func stream(messages: [WireMessage]) -> AsyncThrowingStream<AgentEvent, Error> {
        let request: URLRequest
        do {
            request = try makeRequest(messages: messages)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        return AsyncThrowingStream { continuation in
            let task = Task { [session] in
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else { throw AgentServiceError.badStatus(status) }

                    var parser = SSEParser()
                    for try await byte in bytes {
                        guard let sse = parser.push(byte), let event = try AgentEvent(sse) else {
                            continue
                        }
                        continuation.yield(event)
                        if event.isTerminal {
                            continuation.finish()
                            return
                        }
                    }
                    throw AgentServiceError.streamEndedEarly
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // Fires when the consumer stops iterating or its task is cancelled.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeRequest(messages: [WireMessage]) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "api/runs/stream"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        // Idle timeout between bytes, not a cap on the whole answer.
        request.timeoutInterval = 120
        request.httpBody = try JSONEncoder().encode(["messages": messages])
        return request
    }
}
