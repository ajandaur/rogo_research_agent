import Foundation
import Testing
@testable import RogoResearch

struct AgentEventTests {
    private func decode(_ event: String, _ data: String) throws -> AgentEvent? {
        try AgentEvent(SSEEvent(id: "1", event: event, data: data))
    }

    @Test func decodesEachEventType() throws {
        #expect(try decode("tool_started", #"{"toolUseId":"t1","name":"getFinancials","input":{},"label":"Pulling Initech financials"}"#)
            == .toolStarted(id: "t1", label: "Pulling Initech financials"))
        #expect(try decode("tool_finished", #"{"toolUseId":"t1","name":"getFinancials","durationMs":802}"#)
            == .toolFinished(id: "t1", durationMs: 802))
        #expect(try decode("tool_failed", #"{"toolUseId":"t2","name":"searchDocuments","durationMs":701,"message":"too many terms"}"#)
            == .toolFailed(id: "t2", message: "too many terms"))
        #expect(try decode("text_delta", #"{"text":"\n\n### Head"}"#) == .textDelta("\n\n### Head"))
        #expect(try decode("done", #"{"stopReason":"end_turn"}"#) == .done)
        #expect(try decode("error", #"{"code":"upstream","message":"The model request failed."}"#)
            == .error(message: "The model request failed."))
    }

    @Test func ignoresUnknownEvents() throws {
        #expect(try decode("progress", "{}") == nil)
    }

    @Test func throwsOnMalformedPayload() {
        #expect(throws: DecodingError.self) { try decode("text_delta", "{}") }
    }
}
