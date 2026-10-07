import Foundation
import Observation

@Observable
final class SettingsStore {
    static let defaultModelID = "openai/gpt-4o-mini"
    private static let modelIDKey = "modelID"
    private static let apiKeyAccount = "openrouter"
    private static let launchAtLoginWantedKey = "launchAtLoginWanted"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let keychain: SecretStoring
    @ObservationIgnored private let apiKeySaveDelay: Duration
    @ObservationIgnored private var persistedAPIKey: String
    @ObservationIgnored private var apiKeySaveTask: Task<Void, Never>?

    var modelID: String {
        didSet { defaults.set(modelID, forKey: Self.modelIDKey) }
    }

    /// Saved to the Keychain once typing pauses (or on `flushAPIKey()`), not on every keystroke.
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
        modelID = defaults.string(forKey: Self.modelIDKey) ?? Self.defaultModelID
        persistedAPIKey = keychain.read(account: Self.apiKeyAccount) ?? ""
        apiKey = persistedAPIKey
        launchAtLoginWanted = defaults.object(forKey: Self.launchAtLoginWantedKey) as? Bool ?? true
    }

    /// Writes a pending API key change to the Keychain immediately.
    func flushAPIKey() {
        apiKeySaveTask?.cancel()
        apiKeySaveTask = nil
        guard apiKey != persistedAPIKey else { return }
        if keychain.write(apiKey, account: Self.apiKeyAccount) {
            persistedAPIKey = apiKey
        }
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
