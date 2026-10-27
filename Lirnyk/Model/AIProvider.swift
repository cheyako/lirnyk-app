import Foundation

nonisolated enum AIProvider: String, CaseIterable, Identifiable, Sendable {
    case openRouter = "openrouter"
    case openAI = "openai"
    case anthropic
    case gemini
    case ollama

    static let defaultOllamaServer = "http://localhost:11434"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openRouter: "OpenRouter"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Gemini"
        case .ollama: "Ollama (local)"
        }
    }

    var defaultModelID: String {
        switch self {
        case .openRouter: "openai/gpt-4o-mini"
        case .openAI: "gpt-4.1-mini"
        case .anthropic: "claude-haiku-5-5"
        case .gemini: "gemini-2.5-flash"
        case .ollama: "llama3.2:latest"
        }
    }

    /// Offered in the Model picker, default first; any other ID can still be typed as a custom model.
    var suggestedModelIDs: [String] {
        switch self {
        case .openRouter: [defaultModelID, "anthropic/claude-haiku-5.5", "google/gemini-3.8-flash", "openai/gpt-6.1-terra", "anthropic/claude-sonnet-5.5"]
        case .openAI: [defaultModelID, "gpt-5.4-nano", "gpt-5.4-mini", "gpt-5.5", "gpt-6.1-terra"]
        case .anthropic: [defaultModelID, "claude-sonnet-5-5", "claude-opus-5-5"]
        case .gemini: [defaultModelID, "gemini-3.5-flash-lite", "gemini-3.8-flash"]
        case .ollama: [] // the Model picker lists what the server has installed
        }
    }

    /// Ollama runs locally (or on the user's own server) and needs no key.
    var requiresAPIKey: Bool { self != .ollama }

    /// Base URL of an Ollama server as typed in Settings; a missing scheme means http.
    static func ollamaBaseURL(_ server: String) -> URL? {
        var text = server.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") { text = "http://" + text }
        while text.hasSuffix("/"), !text.hasSuffix("://") { text.removeLast() }
        guard let url = URL(string: text), url.host() != nil else { return nil }
        return url
    }

    /// Keychain account for the provider's API key; `openrouter` predates multi-provider support.
    var keychainAccount: String { rawValue }

    var apiKeysURL: URL {
        switch self {
        case .openRouter: URL(string: "https://openrouter.ai/keys")!
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")!
        case .gemini: URL(string: "https://aistudio.google.com/apikey")!
        case .ollama: URL(string: "https://ollama.com/download")!
        }
    }

    var modelsURL: URL {
        switch self {
        case .openRouter: URL(string: "https://openrouter.ai/models")!
        case .openAI: URL(string: "https://platform.openai.com/docs/models")!
        case .anthropic: URL(string: "https://docs.claude.com/en/docs/about-claude/models/overview")!
        case .gemini: URL(string: "https://ai.google.dev/gemini-api/docs/models")!
        case .ollama: URL(string: "https://ollama.com/library")!
        }
    }
}
