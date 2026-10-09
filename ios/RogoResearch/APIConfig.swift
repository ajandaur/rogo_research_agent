import Foundation

enum APIConfig {
    /// `localhost` reaches your Mac from the simulator. On a physical device, use your Mac's LAN address.
    static let baseURL = URL(string: "http://localhost:8787")!
}
