import Testing
@testable import RogoResearch

struct RogoResearchTests {
    @Test func baseURLPointsAtTheAgentServer() {
        #expect(APIConfig.baseURL.port == 8787)
    }
}
