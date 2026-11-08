import Foundation
import Testing
@testable import Lirnyk

struct ProfileStoreTests {
    let dir = FileManager.default.temporaryDirectory.appending(path: "lirnyk-tests-\(UUID().uuidString)")
    var fileURL: URL { dir.appending(path: "profiles.json") }

    @Test func seedsDefaultsWhenFileMissing() {
        let store = ProfileStore(fileURL: fileURL)
        #expect(store.load())
        #expect(store.profiles.map(\.title) == ["Friendly", "Corporate", "Tech"])
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func roundTripsChanges() {
        let store = ProfileStore(fileURL: fileURL)
        store.load()
        var added = store.add()
        added.title = "Ukr"
        added.prompt = "Переклади українською 🇺🇦"
        store.update(added)
        store.delete(id: store.profiles[0].id)

        let reloaded = ProfileStore(fileURL: fileURL)
        #expect(reloaded.load() == false)
        #expect(reloaded.profiles == store.profiles)
        #expect(reloaded.profiles.map(\.title) == ["Corporate", "Tech", "Ukr"])
        #expect(reloaded.profiles.last?.prompt == "Переклади українською 🇺🇦")
    }

    @Test func untouchedOldDefaultPromptIsUpgraded() throws {
        let old = Profile(title: "Corporate", prompt: DefaultProfiles.corporateV1)
        let edited = Profile(title: "Corporate copy", prompt: DefaultProfiles.corporateV1 + " Be brief.")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try JSONEncoder().encode([old, edited]).write(to: fileURL)

        let store = ProfileStore(fileURL: fileURL)
        #expect(store.load() == false)
        let corporate = try #require(DefaultProfiles.make().first { $0.title == "Corporate" })
        #expect(store.profiles[0].prompt == corporate.prompt)
        #expect(store.profiles[0].id == old.id)
        #expect(store.profiles[1] == edited)

        let reloaded = ProfileStore(fileURL: fileURL)
        reloaded.load()
        #expect(reloaded.profiles == store.profiles)
    }

    @Test func defaultPromptIsFoundByBuiltInTitleOnly() {
        for profile in DefaultProfiles.make() {
            #expect(DefaultProfiles.defaultPrompt(forTitle: profile.title) == profile.prompt)
        }
        #expect(DefaultProfiles.defaultPrompt(forTitle: "Corporate ") != nil)
        #expect(DefaultProfiles.defaultPrompt(forTitle: "Work") == nil)
        #expect(DefaultProfiles.defaultPrompt(forTitle: "") == nil)
    }

    @Test func emptyListIsNotReseeded() {
        let store = ProfileStore(fileURL: fileURL)
        store.load()
        for profile in store.profiles { store.delete(id: profile.id) }

        let reloaded = ProfileStore(fileURL: fileURL)
        #expect(reloaded.load() == false)
        #expect(reloaded.profiles.isEmpty)
    }

    @Test func corruptFileIsBackedUpAndReseeded() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fileURL)

        let store = ProfileStore(fileURL: fileURL)
        #expect(store.load())
        #expect(store.profiles.count == 3)
        let backup = dir.appending(path: "profiles.corrupt.json")
        #expect(try String(contentsOf: backup, encoding: .utf8) == "not json")
    }

    @Test func onChangeFiresOnEveryMutation() {
        let store = ProfileStore(fileURL: fileURL)
        store.load()
        var changes = 0
        store.onChange = { changes += 1 }
        var profile = store.add()
        profile.title = "X"
        store.update(profile)
        store.delete(id: profile.id)
        #expect(changes == 3)
    }
}
