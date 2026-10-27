import Foundation
import Testing
@testable import Lirnyk

struct OllamaSettingsTests {
    let suiteName = "lirnyk-tests-\(UUID().uuidString)"

    @Test(arguments: [
        ("http://localhost:11434", "http://localhost:11434"),
        ("  localhost:11434/ ", "http://localhost:11434"),
        ("https://box.example.com/", "https://box.example.com"),
    ])
    func serverAddressIsNormalised(typed: String, expected: String) {
        #expect(AIProvider.ollamaBaseURL(typed)?.absoluteString == expected)
    }

    @Test(arguments: ["", "   ", "http://"])
    func blankServerAddressIsRejected(typed: String) {
        #expect(AIProvider.ollamaBaseURL(typed) == nil)
    }

    @Test func ollamaNeedsNoKeyAndRemembersServer() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults, keychain: FakeSecrets())
        #expect(!settings.isConfigured)

        settings.provider = .ollama
        #expect(settings.isConfigured)
        #expect(settings.ollamaServer == AIProvider.defaultOllamaServer)
        #expect(settings.modelID == AIProvider.ollama.defaultModelID)

        settings.ollamaServer = "http://studio.local:11434"
        let reloaded = SettingsStore(defaults: defaults, keychain: FakeSecrets())
        #expect(reloaded.provider == .ollama)
        #expect(reloaded.ollamaServer == "http://studio.local:11434")
    }
}

extension NetworkTests {
    struct OllamaClientTests {
        init() { StubURLProtocol.reset() }

        static func client(server: String = "http://localhost:11434") -> AIClient {
            AIClient(session: StubURLProtocol.makeSession()) {
                (provider: .ollama, apiKey: "", model: "llama3.2:latest", server: server)
            }
        }

        @Test func chatGoesToServerWithoutAuthOrKey() async throws {
            StubURLProtocol.handler = { _ in (200, AIClientTests.success("ok")) }

            #expect(try await Self.client(server: "studio.local:11434/").rephrase(text: "hi", systemPrompt: "p") == "ok")

            let request = try #require(StubURLProtocol.lastRequest)
            #expect(request.url?.absoluteString == "http://studio.local:11434/v1/chat/completions")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(request.timeoutInterval == AIClient.ollamaTimeout)
            let body = try #require(StubURLProtocol.lastBody)
            let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["model"] as? String == "llama3.2:latest")
        }

        @Test func refusedConnectionSaysOllamaIsNotRunning() async {
            StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
            await #expect(throws: RephraseError.ollamaUnreachable("localhost:11434")) {
                try await Self.client().rephrase(text: "hi", systemPrompt: "p")
            }
        }

        @Test func invalidServerFailsWithoutNetwork() async {
            await #expect(throws: RephraseError.invalidServer(" ")) {
                try await Self.client(server: " ").rephrase(text: "hi", systemPrompt: "p")
            }
            #expect(StubURLProtocol.lastRequest == nil)
        }

        @Test func installedModelsAreListedSorted() async throws {
            StubURLProtocol.handler = { _ in
                (200, Data(#"{"models":[{"name":"qwen3:8b"},{"name":"llama3.2:latest"}]}"#.utf8))
            }

            let models = try await OllamaModels.installed(server: "localhost:11434", session: StubURLProtocol.makeSession())

            #expect(models == ["llama3.2:latest", "qwen3:8b"])
            #expect(StubURLProtocol.lastRequest?.url?.absoluteString == "http://localhost:11434/api/tags")
        }

        @Test func modelListReportsUnreachableServer() async {
            StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
            await #expect(throws: RephraseError.ollamaUnreachable("localhost:11434")) {
                try await OllamaModels.installed(server: "http://localhost:11434", session: StubURLProtocol.makeSession())
            }
        }
    }
}
