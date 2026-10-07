import Foundation
import Testing
@testable import Lirnyk

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

        let reloaded = SettingsStore(defaults: defaults, keychain: keychain)
        #expect(reloaded.apiKey == "sk-or-test")
        #expect(reloaded.modelID == "anthropic/claude-haiku-4.5")
        #expect(reloaded.hasAPIKey)

        settings.apiKey = "  "
        #expect(!settings.hasAPIKey)
        settings.apiKey = ""
        #expect(keychain.read(account: "openrouter") == nil)
    }
}
