import Testing
@testable import RogoResearch

struct MarkdownParserTests {
    @Test func parsesHeadingsAndParagraphs() {
        #expect(MarkdownParser.parse("## Summary\nFirst line\nsecond line\n\nNext para") == [
            .heading(level: 2, text: "Summary"),
            .paragraph("First line\nsecond line"),
            .paragraph("Next para"),
        ])
    }

    @Test func doesNotTreatHashtagsAsHeadings() {
        #expect(MarkdownParser.parse("#1 rank") == [.paragraph("#1 rank")])
    }

    @Test func groupsBulletsAndKeepsInlineMarkup() {
        #expect(MarkdownParser.parse("### Risks\n- **Debt** is high\n* Churn\nAfter") == [
            .heading(level: 3, text: "Risks"),
            .bullets(["**Debt** is high", "Churn"]),
            .paragraph("After"),
        ])
    }

    @Test func parsesTablesWithAlignmentColonsAndUnevenRows() {
        let text = """
        | Metric | GLBX | ITCH |
        |:---|---:|:---:|
        | Revenue | $8.72B | $988M |
        | Margin | 30% |
        """
        #expect(MarkdownParser.parse(text) == [
            .table(header: ["Metric", "GLBX", "ITCH"], rows: [
                ["Revenue", "$8.72B", "$988M"],
                ["Margin", "30%", ""],
            ]),
        ])
    }

    @Test func tableWithoutSeparatorYetIsAParagraph() {
        // Mid-stream: the separator row hasn't arrived yet.
        #expect(MarkdownParser.parse("| Metric | GLBX | ITCH |\n|") == [
            .paragraph("| Metric | GLBX | ITCH |\n|"),
        ])
        // Outer pipes are optional, so a separator still streaming in already counts.
        #expect(MarkdownParser.parse("| Metric | GLBX | ITCH |\n|---|---|---") == [
            .table(header: ["Metric", "GLBX", "ITCH"], rows: []),
        ])
    }

    @Test func parsesARealAnswer() {
        let blocks = MarkdownParser.parse(SampleAnswers.glbxVsItch)
        let kinds = blocks.map { block -> String in
            switch block {
            case .heading: "heading"
            case .paragraph: "paragraph"
            case .bullets(let items): "bullets(\(items.count))"
            case .table(let header, let rows): "table(\(header.count)x\(rows.count))"
            }
        }
        #expect(kinds == [
            "paragraph",
            "heading", "table(3x6)",
            "heading", "bullets(4)",
            "heading", "bullets(3)",
            "heading", "paragraph",
        ])
    }
}
