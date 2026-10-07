import Testing
@testable import Lirnyk

struct SmokeTests {
    @Test func detectsTestEnvironment() {
        #expect(AppEnvironment.isRunningTests)
    }
}
