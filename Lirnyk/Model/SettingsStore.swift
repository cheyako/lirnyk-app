import Foundation
import Observation

@Observable
final class SettingsStore {
    private static let providerKey = "provider"
    private static let launchAtLoginWantedKey = "launchAtLoginWanted"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let keychain: SecretStoring
    @ObservationIgnored private let apiKeySaveDelay: Duration
    @ObservationIgnored private var persistedAPIKey: String
    @ObservationIgnored private var apiKeySaveTask: Task<Void, Never>?

    /// Switching saves the previous provider's pending key and loads the new provider's key and model.
    var provider: AIProvider {
        didSet {
            guard provider != oldValue else { return }
            defaults.set(provider.rawValue, forKey: Self.providerKey)
            saveAPIKey(for: oldValue)
            loadProviderSettings()
        }
    }

    /// Model for the current provider; each provider remembers its own.
    var modelID: String {
        didSet { defaults.set(modelID, forKey: Self.modelIDKey(for: provider)) }
    }

    /// Key for the current provider. Saved to the Keychain once typing pauses (or on `flushAPIKey()`), not on every keystroke.
    var apiKey: String {
        didSet { scheduleAPIKeySave() }
    }

    /// User preference; the actual SMAppService registration is synced on each launch.
    var launchAtLoginWanted: Bool {
        didSet { defaults.set(launchAtLoginWanted, forKey: Self.launchAtLoginWantedKey) }
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(defaults: UserDefaults = .standard,
         keychain: SecretStoring = Keychain(service: "com.metajourney.lirnyk"),
         apiKeySaveDelay: Duration = .milliseconds(800)) {
        self.defaults = defaults
        self.keychain = keychain
        self.apiKeySaveDelay = apiKeySaveDelay
        let provider = defaults.string(forKey: Self.providerKey).flatMap(AIProvider.init(rawValue:)) ?? .openRouter
        self.provider = provider
        modelID = defaults.string(forKey: Self.modelIDKey(for: provider)) ?? provider.defaultModelID
        persistedAPIKey = keychain.read(account: provider.keychainAccount) ?? ""
        apiKey = persistedAPIKey
        launchAtLoginWanted = defaults.object(forKey: Self.launchAtLoginWantedKey) as? Bool ?? true
    }

    /// Writes a pending API key change to the Keychain immediately.
    func flushAPIKey() {
        saveAPIKey(for: provider)
    }

    /// OpenRouter keeps the pre-multi-provider key so existing settings carry over.
    private static func modelIDKey(for provider: AIProvider) -> String {
        provider == .openRouter ? "modelID" : "modelID.\(provider.rawValue)"
    }

    private func saveAPIKey(for provider: AIProvider) {
        apiKeySaveTask?.cancel()
        apiKeySaveTask = nil
        guard apiKey != persistedAPIKey else { return }
        if keychain.write(apiKey, account: provider.keychainAccount) {
            persistedAPIKey = apiKey
        }
    }

    private func loadProviderSettings() {
        modelID = defaults.string(forKey: Self.modelIDKey(for: provider)) ?? provider.defaultModelID
        persistedAPIKey = keychain.read(account: provider.keychainAccount) ?? ""
        apiKey = persistedAPIKey
        apiKeySaveTask?.cancel()
        apiKeySaveTask = nil
    }

    private func scheduleAPIKeySave() {
        apiKeySaveTask?.cancel()
        let delay = apiKeySaveDelay
        apiKeySaveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.flushAPIKey()
        }
    }
}
