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

    @Test func launchAtLoginWantedDefaultsOnAndPersists() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults, keychain: keychain)
        #expect(settings.launchAtLoginWanted)
        settings.launchAtLoginWanted = false
        #expect(SettingsStore(defaults: defaults, keychain: keychain).launchAtLoginWanted == false)
    }
}
