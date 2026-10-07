import Foundation
import Testing
@testable import Lirnyk

@Suite(.serialized)
struct OpenRouterClientTests {
    let client: OpenRouterClient

    init() {
        StubURLProtocol.reset()
        client = OpenRouterClient(session: StubURLProtocol.makeSession()) {
            (apiKey: " sk-or-123 ", model: "openai/gpt-4o-mini")
        }
    }

    static func success(_ content: String) -> Data {
        let json: [String: Any] = ["choices": [["message": ["role": "assistant", "content": content]]]]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    @Test func sendsExpectedRequest() async throws {
        StubURLProtocol.handler = { _ in (200, Self.success("\n  Привіт 👋 \n")) }

        let result = try await client.rephrase(text: "привіт", systemPrompt: "Be friendly")

        #expect(result == "Привіт 👋")
        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://openrouter.ai/api/v1/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-or-123")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "X-Title") == "Lirnyk")

        let body = try #require(StubURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "openai/gpt-4o-mini")
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [
            ["role": "system", "content": "Be friendly"],
            ["role": "user", "content": "привіт"],
        ])
    }

    @Test func omitsSystemMessageWhenPromptEmpty() async throws {
        StubURLProtocol.handler = { _ in (200, Self.success("ok")) }

        _ = try await client.rephrase(text: "hi", systemPrompt: "  \n")

        let body = try #require(StubURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [["role": "user", "content": "hi"]])
    }

    @Test func missingKeyThrowsWithoutNetwork() async {
        let noKey = OpenRouterClient(session: StubURLProtocol.makeSession()) { (apiKey: "  ", model: "m") }
        StubURLProtocol.handler = { _ in (200, Self.success("ok")) }

        await #expect(throws: RephraseError.missingAPIKey) {
            try await noKey.rephrase(text: "hi", systemPrompt: "p")
        }
        #expect(StubURLProtocol.lastRequest == nil)
    }

    @Test(arguments: [
        (401, RephraseError.unauthorized),
        (402, RephraseError.insufficientCredits),
        (429, RephraseError.rateLimited),
    ])
    func mapsHTTPStatus(status: Int, expected: RephraseError) async {
        StubURLProtocol.handler = { _ in (status, Data("{}".utf8)) }
        await #expect(throws: expected) {
            try await client.rephrase(text: "hi", systemPrompt: "p")
        }
    }

    @Test func serverErrorIncludesMessage() async {
        StubURLProtocol.handler = { _ in (400, Data(#"{"error":{"code":400,"message":"context length exceeded"}}"#.utf8)) }
        await #expect(throws: RephraseError.server(status: 400, message: "context length exceeded")) {
            try await client.rephrase(text: "hi", systemPrompt: "p")
        }
    }

    @Test func errorObjectInside200() async {
        StubURLProtocol.handler = { _ in (200, Data(#"{"error":{"code":502,"message":"Provider returned error"}}"#.utf8)) }
        await #expect(throws: RephraseError.server(status: 200, message: "Provider returned error")) {
            try await client.rephrase(text: "hi", systemPrompt: "p")
        }
    }

    @Test func nullContentIsEmptyResponse() async {
        StubURLProtocol.handler = { _ in (200, Data(#"{"choices":[{"message":{"role":"assistant","content":null}}]}"#.utf8)) }
        await #expect(throws: RephraseError.emptyResponse) {
            try await client.rephrase(text: "hi", systemPrompt: "p")
        }
    }

    @Test func whitespaceOnlyContentIsEmptyResponse() async {
        StubURLProtocol.handler = { _ in (200, Self.success(" \n ")) }
        await #expect(throws: RephraseError.emptyResponse) {
            try await client.rephrase(text: "hi", systemPrompt: "p")
        }
    }

    @Test func timeoutIsMapped() async {
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await #expect(throws: RephraseError.timeout) {
            try await client.rephrase(text: "hi", systemPrompt: "p")
        }
    }
}
