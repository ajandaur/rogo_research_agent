import SwiftUI

struct ContentView: View {
    var body: some View {
        ContentUnavailableView(
            "Rogo Research",
            systemImage: "text.bubble",
            description: Text("Build the chat here. The agent server is at \(APIConfig.baseURL.absoluteString).")
        )
    }
}

#Preview {
    ContentView()
}
