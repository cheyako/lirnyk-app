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
    case emptyResponse
    case cancelled

    var message: String {
        switch self {
        case .accessibilityNotGranted: "Lirnyk needs Accessibility permission"
        case .missingAPIKey: "Add your OpenRouter API key in Settings"
        case .nothingSelected: "Nothing selected"
        case .unauthorized: "OpenRouter rejected the API key (401)"
        case .insufficientCredits: "OpenRouter: insufficient credits (402)"
        case .rateLimited: "OpenRouter rate limit — try again shortly"
        case let .server(status, message): "OpenRouter error \(status): \(message ?? "unknown error")"
        case .timeout: "AI request timed out"
        case let .network(description): "Network error: \(description)"
        case .emptyResponse: "AI returned empty text"
        case .cancelled: "Cancelled"
        }
    }
}
