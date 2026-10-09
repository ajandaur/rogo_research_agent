import Foundation

/// The block-level markdown this app renders. Inline styles (bold, italics,
/// code, links) stay in the strings and are handled by `AttributedString`.
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    /// Lines are kept with their newlines, so numbered lists still read correctly.
    case paragraph(String)
    case bullets([String])
    case table(header: [String], rows: [[String]])
}

enum MarkdownParser {
    /// Parses the whole text. Called again on every streamed delta: a table only
    /// becomes a table once its `|---|` separator line has arrived; until then
    /// its header line renders as a paragraph.
    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: "\n")))
                paragraph = []
            }
        }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                i += 1
            } else if let heading = heading(trimmed) {
                flushParagraph()
                blocks.append(heading)
                i += 1
            } else if let item = bulletItem(trimmed) {
                flushParagraph()
                var items = [item]
                i += 1
                while i < lines.count,
                      let next = bulletItem(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(next)
                    i += 1
                }
                blocks.append(.bullets(items))
            } else if trimmed.contains("|"), i + 1 < lines.count, isSeparator(lines[i + 1]) {
                flushParagraph()
                let header = cells(trimmed)
                var rows: [[String]] = []
                i += 2
                while i < lines.count {
                    let row = lines[i].trimmingCharacters(in: .whitespaces)
                    guard row.contains("|") else { break }
                    rows.append(fit(cells(row), to: header.count))
                    i += 1
                }
                blocks.append(.table(header: header, rows: rows))
            } else {
                paragraph.append(trimmed)
                i += 1
            }
        }
        flushParagraph()
        return blocks
    }

    private static func heading(_ line: String) -> MarkdownBlock? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        guard rest.first == " " else { return nil }
        return .heading(level: hashes, text: rest.trimmingCharacters(in: .whitespaces))
    }

    private static func bulletItem(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    /// `|---|:---:|---:|`, with or without the outer pipes.
    private static func isSeparator(_ line: String) -> Bool {
        let parts = cells(line.trimmingCharacters(in: .whitespaces))
        return !parts.isEmpty && parts.allSatisfy { part in
            let dashes = part.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            return !dashes.isEmpty && dashes.allSatisfy { $0 == "-" }
        }
    }

    private static func cells(_ line: String) -> [String] {
        var row = Substring(line)
        if row.hasPrefix("|") { row = row.dropFirst() }
        if row.hasSuffix("|") { row = row.dropLast() }
        return row.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Pads short rows (e.g. one still streaming in) and trims long ones.
    private static func fit(_ row: [String], to count: Int) -> [String] {
        if row.count >= count { return Array(row.prefix(count)) }
        return row + Array(repeating: "", count: count - row.count)
    }
}
