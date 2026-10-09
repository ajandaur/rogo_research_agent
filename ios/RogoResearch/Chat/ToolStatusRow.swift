import SwiftUI

/// One tool call: spinner while running, then a checkmark with its duration or a warning.
struct ToolStatusRow: View {
    let call: ToolCall

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            icon
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(call.label)
                    .foregroundStyle(call.state == .running ? .primary : .secondary)
                if case .failed(let message) = call.state {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if case .finished(let durationMs) = call.state {
                Text(Duration.milliseconds(durationMs), format: .units(allowed: [.seconds, .milliseconds], width: .narrow))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        switch call.state {
        case .running:
            ProgressView().controlSize(.mini)
        case .finished:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}
