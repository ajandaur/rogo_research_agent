import Foundation
import Testing
@testable import RogoResearch

struct SSEParserTests {
    private func parse(_ chunks: [String]) -> [SSEEvent] {
        var parser = SSEParser()
        return chunks.flatMap { parser.feed(Array($0.utf8)) }
    }

    @Test func parsesAFrame() {
        let events = parse(["id: 1\nevent: text_delta\ndata: {\"text\":\"hi\"}\n\n"])
        #expect(events == [SSEEvent(id: "1", event: "text_delta", data: "{\"text\":\"hi\"}")])
    }

    @Test func waitsForTheBlankLineBeforeDispatching() {
        var parser = SSEParser()
        #expect(parser.feed(Array("event: done\ndata: {}\n".utf8)).isEmpty)
        #expect(parser.feed(Array("\n".utf8)) == [SSEEvent(id: nil, event: "done", data: "{}")])
    }

    @Test func handlesChunksSplitMidLine() {
        let events = parse(["id: 7\nev", "ent: text_del", "ta\ndata: {\"text\":", "\"ab\"}\n", "\n"])
        #expect(events == [SSEEvent(id: "7", event: "text_delta", data: "{\"text\":\"ab\"}")])
    }

    @Test func handlesAMultiByteCharacterSplitAcrossChunks() {
        var parser = SSEParser()
        let bytes = Array("data: a — b\n\n".utf8)
        let dash = bytes.firstIndex(of: 0xE2)!
        // Split inside the three-byte em dash.
        var events = parser.feed(bytes[..<(dash + 1)])
        events += parser.feed(bytes[(dash + 1)...])
        #expect(events.map(\.data) == ["a — b"])
    }

    @Test func acceptsCRLFAndCRLineEndings() {
        #expect(parse(["event: a\r\ndata: 1\r\n\r\n"]) == [SSEEvent(id: nil, event: "a", data: "1")])
        #expect(parse(["event: b\rdata: 2\r\r"]) == [SSEEvent(id: nil, event: "b", data: "2")])
    }

    @Test func ignoresCommentsAndUnknownFields() {
        let events = parse([": ping\n\nretry: 1000\nfoo: bar\ndata: x\n\n"])
        #expect(events == [SSEEvent(id: nil, event: "message", data: "x")])
    }

    @Test func joinsMultipleDataLines() {
        #expect(parse(["data: one\ndata: two\n\n"]).map(\.data) == ["one\ntwo"])
    }

    @Test func parsesConsecutiveEventsAndKeepsTheLastID() {
        let events = parse(["id: 1\nevent: a\ndata: x\n\nevent: b\ndata: y\n\n"])
        #expect(events == [
            SSEEvent(id: "1", event: "a", data: "x"),
            SSEEvent(id: "1", event: "b", data: "y"),
        ])
    }
}
