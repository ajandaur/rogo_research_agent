import SwiftUI

/// Renders block-level markdown: headings, paragraphs, bullet lists and tables.
/// Tables scroll horizontally instead of squeezing columns on a phone.
struct MarkdownView: View {
    private let blocks: [MarkdownBlock]

    init(_ text: String) {
        blocks = MarkdownParser.parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Blocks only ever append or change in place while streaming, so
            // position is a stable identity.
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(level <= 2 ? .title3.bold() : .headline)
                .padding(.top, 4)
        case .paragraph(let text):
            inline(text)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        inline(item)
                    }
                }
            }
        case .table(let header, let rows):
            MarkdownTable(header: header, rows: rows)
        }
    }
}

private struct MarkdownTable: View {
    let header: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    ForEach(header.indices, id: \.self) { column in
                        inline(header[column])
                            .font(.subheadline.bold())
                            .gridColumnAlignment(isNumeric(column) ? .trailing : .leading)
                    }
                }
                ForEach(rows.indices, id: \.self) { row in
                    Divider()
                    GridRow {
                        ForEach(header.indices, id: \.self) { column in
                            inline(rows[row][column])
                                .font(.subheadline)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .lineLimit(1)
            .padding(12)
        }
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Right-align a column when every non-empty body cell looks like a figure.
    private func isNumeric(_ column: Int) -> Bool {
        guard column > 0 else { return false }
        let values = rows.map { $0[column] }.filter { !$0.isEmpty }
        return !values.isEmpty && values.allSatisfy { value in
            value.contains(where: \.isNumber)
                && value.first.map { "$~-+–(0123456789".contains($0) } == true
        }
    }
}

/// Inline markdown (bold, italics, code, links) via AttributedString, falling
/// back to plain text if it doesn't parse.
private func inline(_ text: String) -> Text {
    let options = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    if let attributed = try? AttributedString(markdown: text, options: options) {
        return Text(attributed)
    }
    return Text(text)
}

#if DEBUG
#Preview("GLBX vs ITCH") {
    ScrollView {
        MarkdownView(SampleAnswers.glbxVsItch)
            .padding()
    }
}

#Preview("Mid-stream table") {
    // Cut off partway through the table's rows, as it looks while streaming.
    let text = SampleAnswers.glbxVsItch
    let cut = text.range(of: "| Gross margin")!.lowerBound
    return ScrollView {
        MarkdownView(String(text[..<cut]) + "| Gross marg")
            .padding()
    }
}
#endif
