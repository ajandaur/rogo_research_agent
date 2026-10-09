import SwiftUI

struct MessageRow: View, @MainActor Equatable {
    let message: ChatMessage
    /// Set only on the failed or stopped reply that can be retried.
    var onRetry: (() -> Void)?

    /// Closures can't be compared, so compare the data that's drawn. This lets
    /// SwiftUI skip rows that didn't change while another message streams.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.message == rhs.message && (lhs.onRetry == nil) == (rhs.onRetry == nil)
    }

    var body: some View {
        switch message.role {
        case .user:
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 48)
        case .assistant:
            assistant
        }
    }

    private var assistant: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !message.toolCalls.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(message.toolCalls) { ToolStatusRow(call: $0) }
                }
                .padding(10)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            }

            if !message.text.isEmpty {
                MarkdownView(message.text)
                    .textSelection(.enabled)
            } else if message.status == .streaming && message.toolCalls.isEmpty {
                ProgressView("Thinking…")
                    .font(.subheadline)
            }

            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var footer: some View {
        switch message.status {
        case .failed(let error):
            VStack(alignment: .leading, spacing: 8) {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                if let onRetry {
                    Button("Retry", systemImage: "arrow.clockwise", action: onRetry)
                        .buttonStyle(.bordered)
                }
            }
        case .cancelled:
            HStack(spacing: 12) {
                Label("Stopped", systemImage: "stop.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let onRetry {
                    Button("Retry", systemImage: "arrow.clockwise", action: onRetry)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        case .streaming, .complete:
            EmptyView()
        }
    }
}
