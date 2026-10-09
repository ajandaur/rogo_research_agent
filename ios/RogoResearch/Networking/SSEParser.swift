import Foundation

/// One dispatched server-sent event.
struct SSEEvent: Equatable, Sendable {
    var id: String?
    var event: String
    var data: String
}

/// Incremental parser for a `text/event-stream` body.
///
/// Works on raw bytes rather than `AsyncBytes.lines`, because `lines` skips the
/// blank lines that mark the end of each event. Bytes are buffered until a full
/// line arrives, so a multi-byte UTF-8 character split across network chunks
/// still decodes correctly.
struct SSEParser {
    private var line: [UInt8] = []
    private var previousWasCR = false
    private var lastEventID: String?
    private var eventType: String?
    private var dataLines: [String] = []

    /// Feeds one byte. Returns an event when this byte completes one.
    mutating func push(_ byte: UInt8) -> SSEEvent? {
        // A CRLF pair is one line ending: skip the LF after a CR.
        if previousWasCR {
            previousWasCR = false
            if byte == UInt8(ascii: "\n") { return nil }
        }

        switch byte {
        case UInt8(ascii: "\n"):
            return endLine()
        case UInt8(ascii: "\r"):
            previousWasCR = true
            return endLine()
        default:
            line.append(byte)
            return nil
        }
    }

    /// Feeds a chunk of bytes. Returns every event the chunk completes, in order.
    mutating func feed(_ bytes: some Sequence<UInt8>) -> [SSEEvent] {
        bytes.compactMap { push($0) }
    }

    private mutating func endLine() -> SSEEvent? {
        let text = String(decoding: line, as: UTF8.self)
        line.removeAll(keepingCapacity: true)

        if text.isEmpty { return dispatch() }
        if text.hasPrefix(":") { return nil }  // comment

        let field: Substring
        var value: Substring
        if let colon = text.firstIndex(of: ":") {
            field = text[..<colon]
            value = text[text.index(after: colon)...]
            if value.hasPrefix(" ") { value = value.dropFirst() }
        } else {
            field = text[...]
            value = ""
        }

        switch field {
        case "event": eventType = String(value)
        case "data": dataLines.append(String(value))
        case "id": lastEventID = String(value)
        default: break  // includes "retry", which we don't use
        }
        return nil
    }

    private mutating func dispatch() -> SSEEvent? {
        defer {
            eventType = nil
            dataLines.removeAll()
        }
        guard !dataLines.isEmpty else { return nil }
        return SSEEvent(
            id: lastEventID,
            event: eventType ?? "message",
            data: dataLines.joined(separator: "\n")
        )
    }
}
