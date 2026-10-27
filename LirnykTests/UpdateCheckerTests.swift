import Foundation
import Testing
@testable import Lirnyk

struct AppVersionTests {
    @Test(arguments: [
        ("0.1.0", "0.2.0"),
        ("0.9.9", "0.10.0"),
        ("1.2", "1.2.1"),
        ("v1.9.0", "2.0"),
    ])
    func ordersNumerically(lower: String, higher: String) throws {
        #expect(try #require(AppVersion(lower)) < #require(AppVersion(higher)))
    }

    @Test func missingComponentsAreZero() {
        #expect(AppVersion("1.2") == AppVersion("v1.2.0"))
    }

    @Test(arguments: ["", "v", "1.x", "1..2", "beta"])
    func rejectsNonNumeric(string: String) {
        #expect(AppVersion(string) == nil)
    }
}

extension NetworkTests {
    struct UpdateCheckerTests {
        init() { StubURLProtocol.reset() }

        static func checker(current: String) -> UpdateChecker {
            UpdateChecker(session: StubURLProtocol.makeSession(), currentVersion: current)
        }

        static func release(_ tag: String) -> Data {
            let json = ["tag_name": tag, "html_url": "https://github.com/cheyako/lirnyk-app/releases/tag/\(tag)"]
            return try! JSONSerialization.data(withJSONObject: json)
        }

        @Test func newerReleaseIsAvailable() async throws {
            StubURLProtocol.handler = { _ in (200, Self.release("v0.3.0")) }

            let result = try await Self.checker(current: "0.2.0").check()

            #expect(result == .available(
                version: "0.3.0", url: URL(string: "https://github.com/cheyako/lirnyk-app/releases/tag/v0.3.0")!))
            let request = try #require(StubURLProtocol.lastRequest)
            #expect(request.url == UpdateChecker.latestReleaseURL)
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        }

        @Test(arguments: ["v0.2.0", "v0.1.0"])
        func sameOrOlderReleaseIsUpToDate(tag: String) async throws {
            StubURLProtocol.handler = { _ in (200, Self.release(tag)) }
            #expect(try await Self.checker(current: "0.2.0").check() == .upToDate)
        }

        @Test func httpErrorIsReported() async {
            StubURLProtocol.handler = { _ in (404, Data(#"{"message":"Not Found"}"#.utf8)) }
            await #expect(throws: UpdateCheckError.server(status: 404)) {
                try await Self.checker(current: "0.2.0").check()
            }
        }

        @Test(arguments: ["OK", #"{"tag_name":"nightly","html_url":"https://example.com"}"#])
        func unreadableReleaseIsBadResponse(body: String) async {
            StubURLProtocol.handler = { _ in (200, Data(body.utf8)) }
            await #expect(throws: UpdateCheckError.badResponse) {
                try await Self.checker(current: "0.2.0").check()
            }
        }

        @Test func runningVersionComesFromBundle() {
            #expect(AppVersion(UpdateChecker.currentVersion) != nil)
        }
    }
}
