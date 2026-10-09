import Foundation
import Testing
@testable import RogoResearch

/// Hands out one controllable stream per call and records what was sent.
final class MockAgentService: AgentServicing, @unchecked Sendable {
    typealias Continuation = AsyncThrowingStream<AgentEvent, Error>.Continuation

    private let lock = NSLock()
    private var sent: [[WireMessage]] = []
    private var continuations: [Continuation] = []

    func stream(messages: [WireMessage]) -> AsyncThrowingStream<AgentEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: AgentEvent.self, throwing: Error.self)
        lock.withLock {
            sent.append(messages)
            continuations.append(continuation)
        }
        return stream
    }

    var requests: [[WireMessage]] { lock.withLock { sent } }

    /// Sends `events` on the `call`th stream, then ends it.
    func respond(to call: Int, with events: [AgentEvent]) {
        let continuation = lock.withLock { continuations[call] }
        events.forEach { continuation.yield($0) }
        continuation.finish()
    }
}

@MainActor
struct ChatViewModelTests {
    let service = MockAgentService()
    let model: ChatViewModel

    init() {
        model = ChatViewModel(service: service)
    }

    private func ask(_ text: String) {
        model.draft = text
        model.send()
    }

    @Test func streamsToolsAndTextIntoTheReply() async {
        ask("Is GLBX better than ITCH?")
        #expect(model.runState == .streaming)
        #expect(!model.canSend)

        service.respond(to: 0, with: [
            .toolStarted(id: "t1", label: "Pulling Globex Inc financials"),
            .toolStarted(id: "t2", label: "Pulling Initech financials"),
            .toolFinished(id: "t1", durationMs: 802),
            .toolFailed(id: "t2", message: "boom"),
            .textDelta("No — "),
            .textDelta("Initech."),
            .done,
        ])
        await model.waitForRun()

        let reply = model.messages[1]
        #expect(reply.text == "No — Initech.")
        #expect(reply.toolCalls.map(\.state) == [.finished(durationMs: 802), .failed(message: "boom")])
        #expect(reply.status == .complete)
        #expect(model.runState == .idle)
        #expect(model.draft.isEmpty)
    }

    @Test func serverErrorFailsTheTurnAndRetryAsksAgain() async {
        ask("Umbrella risks?")
        service.respond(to: 0, with: [.textDelta("partial"), .error(message: "The model request failed.")])
        await model.waitForRun()

        #expect(model.runState == .failed(message: "The model request failed."))
        #expect(model.messages[1].status == .failed(message: "The model request failed."))

        model.retry()
        #expect(model.messages.count == 2)  // failed reply replaced by a fresh one
        service.respond(to: 1, with: [.textDelta("Acquisitions."), .done])
        await model.waitForRun()

        #expect(service.requests[1] == [WireMessage(role: .user, content: "Umbrella risks?")])
        #expect(model.messages.map(\.text) == ["Umbrella risks?", "Acquisitions."])
        #expect(model.runState == .idle)
    }

    @Test func streamEndingWithoutDoneIsAFailure() async {
        ask("Hi")
        service.respond(to: 0, with: [.textDelta("cut off")])
        await model.waitForRun()

        guard case .failed = model.runState else {
            Issue.record("expected failed, got \(model.runState)")
            return
        }
    }

    @Test func followUpSendsCompletedTurnsButNotCancelledOnes() async throws {
        ask("Compare Acme and Globex")
        service.respond(to: 0, with: [.textDelta("Acme."), .done])
        await model.waitForRun()

        ask("Umbrella?")
        model.cancel()

        ask("And Initech?")
        // Requests start synchronously in send(), so all three exist already.
        try #require(service.requests.count == 3)
        #expect(service.requests[2] == [
            WireMessage(role: .user, content: "Compare Acme and Globex"),
            WireMessage(role: .assistant, content: "Acme."),
            WireMessage(role: .user, content: "And Initech?"),
        ])
    }

    @Test func cancelStopsTheRunAndIgnoresLateEvents() async {
        ask("Umbrella risks?")
        model.cancel()
        #expect(model.runState == .idle)
        #expect(model.messages[1].status == .cancelled)

        // Run 2 starts while run 1's events are still arriving.
        ask("Initech?")
        service.respond(to: 0, with: [.textDelta("stale"), .done])
        service.respond(to: 1, with: [.textDelta("fresh"), .done])
        await model.waitForRun()
        await Task.yield()

        #expect(model.messages[1].text.isEmpty)
        #expect(model.messages[1].status == .cancelled)
        #expect(model.messages[3].text == "fresh")
        #expect(model.messages[3].status == .complete)
        #expect(model.runState == .idle)
    }

    @Test func retryAfterStopAsksTheSameQuestion() async throws {
        ask("Umbrella risks?")
        #expect(!model.canRetry)
        model.cancel()
        #expect(model.canRetry)

        model.retry()
        try #require(service.requests.count == 2)
        #expect(service.requests[1] == [WireMessage(role: .user, content: "Umbrella risks?")])
        #expect(model.messages.count == 2)  // stopped reply replaced by a fresh one
        #expect(model.messages[1].status == .streaming)
    }

    @Test func noRetryAfterACompletedAnswer() async {
        ask("Hi")
        service.respond(to: 0, with: [.textDelta("Hello."), .done])
        await model.waitForRun()
        #expect(!model.canRetry)
    }

    @Test func newConversationClearsEverything() {
        ask("Hello")
        model.newConversation()
        #expect(model.messages.isEmpty)
        #expect(model.runState == .idle)
    }
}
