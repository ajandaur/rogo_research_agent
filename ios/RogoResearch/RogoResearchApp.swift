import SwiftUI

@main
struct RogoResearchApp: App {
    @State private var model = ChatViewModel(
        service: URLSessionAgentService(baseURL: APIConfig.baseURL)
    )

    var body: some Scene {
        WindowGroup {
            ChatView(model: model)
        }
    }
}
