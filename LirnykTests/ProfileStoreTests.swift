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
