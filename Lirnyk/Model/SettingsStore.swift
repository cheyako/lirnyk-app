import Foundation
import Observation

@Observable
final class SettingsStore {
    static let defaultModelID = "openai/gpt-4o-mini"
    private static let modelIDKey = "modelID"
    private static let apiKeyAccount = "openrouter"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let keychain: Keychain

    var modelID: String {
        didSet { defaults.set(modelID, forKey: Self.modelIDKey) }
    }

    var apiKey: String {
        didSet { keychain.write(apiKey, account: Self.apiKeyAccount) }
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(defaults: UserDefaults = .standard,
         keychain: Keychain = Keychain(service: "com.metajourney.lirnyk")) {
        self.defaults = defaults
        self.keychain = keychain
        modelID = defaults.string(forKey: Self.modelIDKey) ?? Self.defaultModelID
        apiKey = keychain.read(account: Self.apiKeyAccount) ?? ""
    }
}
