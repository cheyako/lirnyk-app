import Foundation

nonisolated enum AIProvider: String, CaseIterable, Identifiable, Sendable {
    case openRouter = "openrouter"
    case openAI = "openai"
    case anthropic
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openRouter: "OpenRouter"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Gemini"
        }
    }

    var defaultModelID: String {
        switch self {
        case .openRouter: "openai/gpt-4o-mini"
        case .openAI: "gpt-4.1-mini"
        case .anthropic: "claude-haiku-5-5"
        case .gemini: "gemini-2.5-flash"
        }
    }

    /// Keychain account for the provider's API key; `openrouter` predates multi-provider support.
    var keychainAccount: String { rawValue }

    var apiKeysURL: URL {
        switch self {
        case .openRouter: URL(string: "https://openrouter.ai/keys")!
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")!
        case .gemini: URL(string: "https://aistudio.google.com/apikey")!
        }
    }

    var modelsURL: URL {
        switch self {
        case .openRouter: URL(string: "https://openrouter.ai/models")!
        case .openAI: URL(string: "https://platform.openai.com/docs/models")!
        case .anthropic: URL(string: "https://docs.claude.com/en/docs/about-claude/models/overview")!
        case .gemini: URL(string: "https://ai.google.dev/gemini-api/docs/models")!
        }
    }
}
