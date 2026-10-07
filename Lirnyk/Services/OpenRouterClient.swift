import Foundation

protocol RephraseClient: AnyObject {
    func rephrase(text: String, systemPrompt: String) async throws -> String
}

final class OpenRouterClient: RephraseClient {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    private let session: URLSession
    private let credentials: () -> (apiKey: String, model: String)

    init(session: URLSession = .shared, credentials: @escaping () -> (apiKey: String, model: String)) {
        self.session = session
        self.credentials = credentials
    }

    func rephrase(text: String, systemPrompt: String) async throws -> String {
        let (rawKey, model) = credentials()
        let apiKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { throw RephraseError.missingAPIKey }

        var messages: [ChatMessage] = []
        if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        messages.append(ChatMessage(role: "user", content: text))

        var request = URLRequest(url: Self.endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Lirnyk", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONEncoder().encode(ChatRequest(model: model, messages: messages))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw RephraseError.timeout
        } catch let error as URLError where error.code == .cancelled {
            throw RephraseError.cancelled
        } catch is CancellationError {
            throw RephraseError.cancelled
        } catch {
            throw RephraseError.network(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data)
        switch status {
        case 200..<300: break
        case 401: throw RephraseError.unauthorized
        case 402: throw RephraseError.insufficientCredits
        case 429: throw RephraseError.rateLimited
        default: throw RephraseError.server(status: status, message: decoded?.error?.message)
        }
        if let apiError = decoded?.error {
            throw RephraseError.server(status: status, message: apiError.message)
        }

        let content = decoded?.choices?.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else { throw RephraseError.emptyResponse }
        return content
    }
}

private nonisolated struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private nonisolated struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
}

private nonisolated struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    struct APIError: Decodable { let message: String? }

    let choices: [Choice]?
    let error: APIError?
}
