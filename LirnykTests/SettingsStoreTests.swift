import Foundation
import Testing
@testable import Lirnyk

final class FakeSecrets: SecretStoring {
    var values: [String: String] = [:]
    var writes: [String?] = []
    func read(account: String) -> String? { values[account] }
    func write(_ value: String?, account: String) -> Bool {
        writes.append(value)
        values[account] = (value?.isEmpty ?? true) ? nil : value
        return true
    }
}

struct SettingsStoreTests {
    let suiteName = "lirnyk-tests-\(UUID().uuidString)"
    let keychain = Keychain(service: "com.metajourney.lirnyk.tests.\(UUID().uuidString)")

    @Test func defaultsPersistAndClear() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            keychain.write(nil, account: "openrouter")
        }

        let settings = SettingsStore(defaults: defaults, keychain: keychain)
        #expect(settings.provider == .openRouter)
        #expect(settings.modelID == "openai/gpt-4o-mini")
        #expect(!settings.hasAPIKey)

        settings.apiKey = "sk-or-test"
        settings.modelID = "anthropic/claude-haiku-4.5"
        settings.flushAPIKey()

        let reloaded = SettingsStore(defaults: defaults, keychain: keychain)
        #expect(reloaded.apiKey == "sk-or-test")
        #expect(reloaded.modelID == "anthropic/claude-haiku-4.5")
        #expect(reloaded.hasAPIKey)

        settings.apiKey = "  "
        #expect(!settings.hasAPIKey)
        settings.apiKey = ""
        settings.flushAPIKey()
        #expect(keychain.read(account: "openrouter") == nil)
    }

    @Test func typingTheKeyWritesKeychainOnce() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let secrets = FakeSecrets()
        let settings = SettingsStore(defaults: defaults, keychain: secrets)

        for prefix in ["s", "sk", "sk-", "sk-or", "sk-or-1"] { settings.apiKey = prefix }
        settings.flushAPIKey()
        settings.flushAPIKey()

        #expect(secrets.writes == ["sk-or-1"])
    }

    @Test func pendingKeyIsSavedAfterTypingPauses() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let secrets = FakeSecrets()
        let settings = SettingsStore(defaults: defaults, keychain: secrets, apiKeySaveDelay: .milliseconds(10))

        settings.apiKey = "sk-or-2"
        try await Task.sleep(for: .milliseconds(200))

        #expect(secrets.writes == ["sk-or-2"])
    }

    @Test func keychainOverwritesAndDeletes() {
        defer { keychain.write(nil, account: "openrouter") }
        #expect(keychain.write("first", account: "openrouter"))
        #expect(keychain.write("second", account: "openrouter"))
        #expect(keychain.read(account: "openrouter") == "second")
        #expect(keychain.write(nil, account: "openrouter"))
        #expect(keychain.read(account: "openrouter") == nil)
        #expect(keychain.write(nil, account: "openrouter"))
    }

    @Test func eachProviderKeepsItsOwnKeyAndModel() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let secrets = FakeSecrets()
        secrets.values["openrouter"] = "sk-or-old"
        defaults.set("anthropic/claude-haiku-4.5", forKey: "modelID")
        let settings = SettingsStore(defaults: defaults, keychain: secrets)

        settings.provider = .anthropic
        #expect(settings.apiKey == "")
        #expect(settings.modelID == AIProvider.anthropic.defaultModelID)
        settings.apiKey = "sk-ant-1"
        settings.modelID = "claude-sonnet-5-5"

        settings.provider = .openRouter
        #expect(secrets.values["anthropic"] == "sk-ant-1")
        #expect(settings.apiKey == "sk-or-old")
        #expect(settings.modelID == "anthropic/claude-haiku-4.5")

        let reloaded = SettingsStore(defaults: defaults, keychain: secrets)
        #expect(reloaded.provider == .openRouter)
        reloaded.provider = .anthropic
        #expect(reloaded.apiKey == "sk-ant-1")
        #expect(reloaded.modelID == "claude-sonnet-5-5")
        #expect(SettingsStore(defaults: defaults, keychain: secrets).provider == .anthropic)
        #expect(secrets.writes == ["sk-ant-1"])
    }

    @Test func unknownSavedProviderFallsBackToOpenRouter() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("github", forKey: "provider")

        let settings = SettingsStore(defaults: defaults, keychain: FakeSecrets())

        #expect(settings.provider == .openRouter)
        #expect(settings.modelID == AIProvider.openRouter.defaultModelID)
    }

    @Test func switchingProviderCancelsPendingSaveForOldProvider() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let secrets = FakeSecrets()
        let settings = SettingsStore(defaults: defaults, keychain: secrets, apiKeySaveDelay: .milliseconds(10))

        settings.apiKey = "sk-or-3"
        settings.provider = .gemini
        try await Task.sleep(for: .milliseconds(100))

        #expect(secrets.values == ["openrouter": "sk-or-3"])
        #expect(secrets.writes == ["sk-or-3"])
    }

    @Test func launchAtLoginWantedDefaultsOnAndPersists() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults, keychain: keychain)
        #expect(settings.launchAtLoginWanted)
        settings.launchAtLoginWanted = false
        #expect(SettingsStore(defaults: defaults, keychain: keychain).launchAtLoginWanted == false)
    }
}
