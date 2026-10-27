import Foundation

nonisolated enum RephraseError: Error, Equatable, Sendable {
    case accessibilityNotGranted
    case missingAPIKey
    case nothingSelected
    case unauthorized
    case insufficientCredits
    case rateLimited
    case server(status: Int, message: String?)
    case timeout
    case network(String)
    case ollamaUnreachable(String)
    case invalidServer(String)
    case emptyResponse
    case truncated
    case contentFiltered
    case cancelled

    var message: String {
        switch self {
        case .accessibilityNotGranted: "Lirnyk needs Accessibility permission"
        case .missingAPIKey: "Add your API key in Settings"
        case .nothingSelected: "Nothing selected"
        case .unauthorized: "The AI provider rejected the API key (401)"
        case .insufficientCredits: "AI provider: insufficient credits (402)"
        case .rateLimited: "AI provider rate limit — try again shortly"
        case let .server(status, message): "AI provider error \(status): \(message ?? "unknown error")"
        case .timeout: "AI request timed out"
        case let .network(description): "Network error: \(description)"
        case let .ollamaUnreachable(server): "Can't reach Ollama at \(server). Is it running?"
        case let .invalidServer(server): "\"\(server)\" isn't a valid server address"
        case .emptyResponse: "AI returned empty text"
        case .truncated: "AI answer was cut off — nothing replaced"
        case .contentFiltered: "AI provider filtered the answer — nothing replaced"
        case .cancelled: "Cancelled"
        }
    }
}
