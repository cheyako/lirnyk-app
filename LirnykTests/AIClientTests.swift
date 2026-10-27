import Foundation
import Testing
@testable import Lirnyk

extension NetworkTests {
    struct AIClientTests {
        let client: AIClient

        init() {
            StubURLProtocol.reset()
            client = AIClient(session: StubURLProtocol.makeSession()) {
                (provider: .openRouter, apiKey: " sk-or-123 ", model: "openai/gpt-4o-mini", server: "")
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
            let noKey = AIClient(session: StubURLProtocol.makeSession()) { (provider: .openAI, apiKey: "  ", model: "m", server: "") }
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

        @Test(arguments: [
            ("<html>Moved</html>", "unexpected response: <html>Moved</html>"),
            (#"{"choices":[]}"#, #"unexpected response: {"choices":[]}"#),
            ("", "unexpected response: (empty body)"),
        ])
        func unexpectedBodyIsReported(body: String, message: String) async {
            StubURLProtocol.handler = { _ in (200, Data(body.utf8)) }
            await #expect(throws: RephraseError.server(status: 200, message: message)) {
                try await client.rephrase(text: "hi", systemPrompt: "p")
            }
        }

        @Test func anthropicUnexpectedBodyIsReported() async {
            StubURLProtocol.handler = { _ in (200, Data("{}".utf8)) }
            await #expect(throws: RephraseError.server(status: 200, message: "unexpected response: {}")) {
                try await Self.client(.anthropic).rephrase(text: "hi", systemPrompt: "p")
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
}

extension NetworkTests.AIClientTests {
    static func response(content: String, finishReason: String?) -> Data {
        var choice: [String: Any] = ["message": ["role": "assistant", "content": content]]
        if let finishReason { choice["finish_reason"] = finishReason }
        return try! JSONSerialization.data(withJSONObject: ["choices": [choice]])
    }

    @Test func truncatedAnswerIsRejected() async {
        StubURLProtocol.handler = { _ in (200, Self.response(content: "Half an ans", finishReason: "length")) }
        await #expect(throws: RephraseError.truncated) {
            try await client.rephrase(text: "hi", systemPrompt: "p")
        }
    }

    @Test func filteredAnswerIsRejected() async {
        StubURLProtocol.handler = { _ in (200, Self.response(content: "[removed]", finishReason: "content_filter")) }
        await #expect(throws: RephraseError.contentFiltered) {
            try await client.rephrase(text: "hi", systemPrompt: "p")
        }
    }

    @Test(arguments: ["stop", nil])
    func normalFinishIsAccepted(finishReason: String?) async throws {
        StubURLProtocol.handler = { _ in (200, Self.response(content: "Done", finishReason: finishReason)) }
        #expect(try await client.rephrase(text: "hi", systemPrompt: "p") == "Done")
    }
}

extension NetworkTests.AIClientTests {
    static func client(_ provider: AIProvider, model: String = "m") -> AIClient {
        AIClient(session: StubURLProtocol.makeSession()) { (provider: provider, apiKey: "key-1", model: model, server: "") }
    }

    @Test(arguments: [
        (AIProvider.openAI, "https://api.openai.com/v1/chat/completions"),
        (AIProvider.gemini, "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"),
    ])
    func chatCompletionsProvidersUseBearerAuth(provider: AIProvider, url: String) async throws {
        StubURLProtocol.handler = { _ in (200, Self.success("ok")) }

        #expect(try await Self.client(provider, model: "gpt-x").rephrase(text: "hi", systemPrompt: "p") == "ok")

        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == url)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer key-1")
        #expect(request.value(forHTTPHeaderField: "X-Title") == nil)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        let body = try #require(StubURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "gpt-x")
    }

    /// A non-JSON 2xx body (e.g. a health-check "OK") is not a completion and must never be pasted.
    @Test(arguments: [AIProvider.openAI, .gemini])
    func plainTextBodyIsRejected(provider: AIProvider) async {
        StubURLProtocol.handler = { _ in (200, Data("OK".utf8)) }
        await #expect(throws: RephraseError.server(status: 200, message: "unexpected response: OK")) {
            try await Self.client(provider).rephrase(text: "hi", systemPrompt: "p")
        }
    }

    @Test func geminiArrayWrappedErrorIsMapped() async {
        StubURLProtocol.handler = { _ in (400, Data(#"[{"error":{"code":400,"message":"API key not valid"}}]"#.utf8)) }
        await #expect(throws: RephraseError.server(status: 400, message: "API key not valid")) {
            try await Self.client(.gemini).rephrase(text: "hi", systemPrompt: "p")
        }
    }

    static func anthropicResponse(_ text: String, stopReason: String = "end_turn") -> Data {
        let json: [String: Any] = [
            "type": "message", "role": "assistant", "stop_reason": stopReason,
            "content": [["type": "text", "text": text]],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    @Test func anthropicSendsMessagesRequest() async throws {
        StubURLProtocol.handler = { _ in (200, Self.anthropicResponse(" Привіт \n")) }

        let result = try await Self.client(.anthropic, model: "claude-haiku-5-5")
            .rephrase(text: "привіт", systemPrompt: "Be friendly")

        #expect(result == "Привіт")
        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "key-1")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

        let body = try #require(StubURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "claude-haiku-5-5")
        #expect(json["system"] as? String == "Be friendly")
        #expect(json["max_tokens"] as? Int == AIClient.anthropicMaxTokens)
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [["role": "user", "content": "привіт"]])
    }

    @Test func anthropicOmitsEmptySystemPrompt() async throws {
        StubURLProtocol.handler = { _ in (200, Self.anthropicResponse("ok")) }
        _ = try await Self.client(.anthropic).rephrase(text: "hi", systemPrompt: " ")
        let body = try #require(StubURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["system"] == nil)
    }

    @Test(arguments: [
        ("max_tokens", RephraseError.truncated),
        ("refusal", RephraseError.contentFiltered),
    ])
    func anthropicStopReasonsAreRejected(stopReason: String, expected: RephraseError) async {
        StubURLProtocol.handler = { _ in (200, Self.anthropicResponse("partial", stopReason: stopReason)) }
        await #expect(throws: expected) {
            try await Self.client(.anthropic).rephrase(text: "hi", systemPrompt: "p")
        }
    }

    @Test func anthropicErrorIncludesMessage() async {
        let body = #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#
        StubURLProtocol.handler = { _ in (529, Data(body.utf8)) }
        await #expect(throws: RephraseError.server(status: 529, message: "Overloaded")) {
            try await Self.client(.anthropic).rephrase(text: "hi", systemPrompt: "p")
        }
    }

    @Test func anthropicUnauthorizedIsMapped() async {
        StubURLProtocol.handler = { _ in (401, Data(#"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#.utf8)) }
        await #expect(throws: RephraseError.unauthorized) {
            try await Self.client(.anthropic).rephrase(text: "hi", systemPrompt: "p")
        }
    }
}
