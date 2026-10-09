import SwiftUI

struct ChatView: View {
    @Bindable var model: ChatViewModel

    private static let suggestions = [
        "Compare Acme and Globex and tell me which one appears to be growing faster.",
        "What are the biggest risks Umbrella Health flags in its filings?",
        "How is Initech's subscription transition going?",
        "Which company in the universe is growing fastest?",
        "Is GLBX a better business than ITCH?",
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(model.messages) { message in
                            MessageRow(message: message, onRetry: retryAction(for: message))
                                .equatable()
                        }
                        Color.clear.frame(height: 1).id(Self.bottomID)
                    }
                    .padding()
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .overlay {
                    if model.messages.isEmpty { emptyState }
                }
                // Follow the answer as it streams in.
                .onChange(of: model.messages.last?.text) {
                    proxy.scrollTo(Self.bottomID, anchor: .bottom)
                }
                .onChange(of: model.messages.count) {
                    withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Composer(model: model)
            }
            .navigationTitle("Rogo Research")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New conversation", systemImage: "square.and.pencil") {
                        model.newConversation()
                    }
                    .disabled(model.messages.isEmpty)
                }
            }
        }
    }

    private static let bottomID = "bottom"

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Ask about a company", systemImage: "text.bubble")
        } description: {
            Text("Rogo researches profiles, financials and filings, then answers.")
        } actions: {
            VStack(spacing: 8) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        model.draft = suggestion
                        model.send()
                    }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func retryAction(for message: ChatMessage) -> (() -> Void)? {
        guard model.canRetry, message.id == model.messages.last?.id else {
            return nil
        }
        return { model.retry() }
    }
}
