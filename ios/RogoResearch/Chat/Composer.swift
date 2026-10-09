import SwiftUI

/// Text field plus a button that sends, or stops the answer while one is streaming.
struct Composer: View {
    @Bindable var model: ChatViewModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask about a company", text: $model.draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.background, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary))

            if model.runState == .streaming {
                Button("Stop", systemImage: "stop.circle.fill") {
                    model.cancel()
                }
            } else {
                Button("Send", systemImage: "arrow.up.circle.fill") {
                    model.send()
                    focused = false
                }
                .disabled(!model.canSend)
            }
        }
        .labelStyle(.iconOnly)
        .font(.title)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
