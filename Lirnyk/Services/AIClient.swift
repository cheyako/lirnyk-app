import Foundation

protocol RephraseClient: AnyObject {
    func rephrase(text: String, systemPrompt: String) async throws -> String
}

/// Talks to the selected provider: OpenRouter, OpenAI, Gemini and Ollama through the OpenAI-compatible
/// chat completions API, Anthropic through its Messages API.
final class AIClient: RephraseClient {
    /// `server` is the Ollama server address; other providers ignore it.
    typealias Credentials = (provider: AIProvider, apiKey: String, model: String, server: String)

    static let anthropicVersion = "2023-06-01"
    static let anthropicMaxTokens = 8192
    /// Local models can take a while to load into memory on first use.
    static let ollamaTimeout: TimeInterval = 120

    /// Nil only for an Ollama server address that isn't a URL.
    static func endpoint(for provider: AIProvider, server: String = AIProvider.defaultOllamaServer) -> URL? {
        switch provider {
        case .openRouter: URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        case .openAI: URL(string: "https://api.openai.com/v1/chat/completions")!
        case .anthropic: URL(string: "https://api.anthropic.com/v1/messages")!
        case .gemini: URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")!
        case .ollama: AIProvider.ollamaBaseURL(server)?.appending(path: "v1/chat/completions")
        }
    }

    private let session: URLSession
    private let credentials: () -> Credentials

    init(session: URLSession = .shared, credentials: @escaping () -> Credentials) {
        self.session = session
        self.credentials = credentials
    }

    func rephrase(text: String, systemPrompt: String) async throws -> String {
        let (provider, rawKey, model, server) = credentials()
        let apiKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty || !provider.requiresAPIKey else { throw RephraseError.missingAPIKey }
        guard let url = Self.endpoint(for: provider, server: server) else { throw RephraseError.invalidServer(server) }
        let system = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : systemPrompt

        var request = URLRequest(url: url, timeoutInterval: provider == .ollama ? Self.ollamaTimeout : 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        switch provider {
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
            request.httpBody = try JSONEncoder().encode(MessagesRequest(
                model: model, maxTokens: Self.anthropicMaxTokens, system: system,
                messages: [ChatMessage(role: "user", content: text)]))
        case .openRouter, .openAI, .gemini, .ollama:
            if provider.requiresAPIKey { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
            if provider == .openRouter { request.setValue("Lirnyk", forHTTPHeaderField: "X-Title") }
            var messages: [ChatMessage] = []
            if let system { messages.append(ChatMessage(role: "system", content: system)) }
            messages.append(ChatMessage(role: "user", content: text))
            request.httpBody = try JSONEncoder().encode(ChatRequest(model: model, messages: messages))
        }

        let (data, status) = try await send(request, to: provider)
        let content = switch provider {
        case .anthropic: try Self.parseMessages(data, status: status)
        case .openRouter, .openAI, .gemini, .ollama: try Self.parseChat(data, status: status)
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RephraseError.emptyResponse }
        return trimmed
    }

    private func send(_ request: URLRequest, to provider: AIProvider) async throws -> (Data, Int) {
        do {
            let (data, response) = try await session.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch let error as URLError where provider == .ollama && OllamaModels.isUnreachable(error) {
            throw RephraseError.ollamaUnreachable(OllamaModels.serverName(request.url))
        } catch let error as URLError where error.code == .timedOut {
            throw RephraseError.timeout
        } catch let error as URLError where error.code == .cancelled {
            throw RephraseError.cancelled
        } catch is CancellationError {
            throw RephraseError.cancelled
        } catch {
            throw RephraseError.network(error.localizedDescription)
        }
    }

    private static func checkStatus(_ status: Int, message: String?) throws {
        switch status {
        case 200..<300: break
        case 401: throw RephraseError.unauthorized
        case 402: throw RephraseError.insufficientCredits
        case 429: throw RephraseError.rateLimited
        default: throw RephraseError.server(status: status, message: message)
        }
    }

    private static func parseChat(_ data: Data, status: Int) throws -> String {
        // Gemini's compatibility layer sometimes wraps errors in a one-element array.
        let decoded = (try? JSONDecoder().decode(ChatResponse.self, from: data))
            ?? (try? JSONDecoder().decode([ChatResponse].self, from: data))?.first
        try checkStatus(status, message: decoded?.error?.message)
        if let apiError = decoded?.error {
            throw RephraseError.server(status: status, message: apiError.message)
        }

        guard let choice = decoded?.choices?.first else { throw unexpectedResponse(data, status: status) }

        switch choice.finishReason {
        case "length": throw RephraseError.truncated
        case "content_filter": throw RephraseError.contentFiltered
        default: break
        }
        return choice.message.content ?? ""
    }

    private static func parseMessages(_ data: Data, status: Int) throws -> String {
        let decoded = try? JSONDecoder().decode(MessagesResponse.self, from: data)
        try checkStatus(status, message: decoded?.error?.message)
        if let apiError = decoded?.error {
            throw RephraseError.server(status: status, message: apiError.message)
        }

        guard let decoded, let content = decoded.content else { throw unexpectedResponse(data, status: status) }

        switch decoded.stopReason {
        case "max_tokens": throw RephraseError.truncated
        case "refusal": throw RephraseError.contentFiltered
        default: break
        }
        return content.filter { $0.type == "text" }.compactMap(\.text).joined()
    }

    /// A 2xx body without the expected shape; shows its start so the cause is visible in the HUD.
    private static func unexpectedResponse(_ data: Data, status: Int) -> RephraseError {
        let body = String(decoding: data.prefix(200), as: UTF8.self)
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        return .server(status: status, message: "unexpected response: \(body.isEmpty ? "(empty body)" : body)")
    }
}

/// Lists the models installed on an Ollama server.
enum OllamaModels {
    static func installed(server: String, session: URLSession = .shared) async throws -> [String] {
        guard let url = AIProvider.ollamaBaseURL(server)?.appending(path: "api/tags") else {
            throw RephraseError.invalidServer(server)
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: URLRequest(url: url, timeoutInterval: 5))
        } catch let error as URLError where isUnreachable(error) || error.code == .timedOut {
            throw RephraseError.ollamaUnreachable(serverName(url))
        } catch {
            throw RephraseError.network(error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status), let tags = try? JSONDecoder().decode(OllamaTags.self, from: data) else {
            throw RephraseError.server(status: status, message: "unexpected response from Ollama")
        }
        return tags.models.map(\.name).sorted()
    }

    static func isUnreachable(_ error: URLError) -> Bool {
        [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet].contains(error.code)
    }

    /// "localhost:11434" for messages.
    static func serverName(_ url: URL?) -> String {
        guard let host = url?.host() else { return "the server" }
        return url?.port.map { "\(host):\($0)" } ?? host
    }
}

private nonisolated struct OllamaTags: Decodable {
    struct Model: Decodable { let name: String }
    let models: [Model]
}

private nonisolated struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private nonisolated struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
}

private nonisolated struct APIError: Decodable { let message: String? }

private nonisolated struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    let choices: [Choice]?
    let error: APIError?
}

private nonisolated struct MessagesRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String?
    let messages: [ChatMessage]

    enum CodingKeys: String, CodingKey {
        case model, system, messages
        case maxTokens = "max_tokens"
    }
}

private nonisolated struct MessagesResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }

    let content: [Block]?
    let stopReason: String?
    let error: APIError?

    enum CodingKeys: String, CodingKey {
        case content, error
        case stopReason = "stop_reason"
    }
}
