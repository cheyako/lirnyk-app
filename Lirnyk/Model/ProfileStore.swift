import Foundation
import Observation
import os

@Observable
final class ProfileStore {
    private(set) var profiles: [Profile] = []
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let logger = Logger(subsystem: "com.metajourney.lirnyk", category: "profiles")

    static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "Lirnyk/profiles.json")
    }

    init(fileURL: URL = ProfileStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    /// Loads profiles from disk. Seeds defaults when the file is missing or corrupt.
    /// - Returns: `true` if defaults were seeded.
    @discardableResult
    func load() -> Bool {
        if let data = try? Data(contentsOf: fileURL) {
            if let decoded = try? JSONDecoder().decode([Profile].self, from: data) {
                profiles = decoded
                return false
            }
            backUpCorruptFile()
        }
        profiles = DefaultProfiles.make()
        persist()
        return true
    }

    @discardableResult
    func add() -> Profile {
        let profile = Profile(title: "New Profile", prompt: "")
        profiles.append(profile)
        save()
        return profile
    }

    func update(_ profile: Profile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        save()
    }

    func delete(id: UUID) {
        profiles.removeAll { $0.id == id }
        save()
    }

    private func save() {
        persist()
        onChange?()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(profiles).write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save profiles: \(error.localizedDescription)")
        }
    }

    private func backUpCorruptFile() {
        let backup = fileURL.deletingLastPathComponent().appending(path: "profiles.corrupt.json")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: fileURL, to: backup)
        logger.error("profiles.json was corrupt; moved to profiles.corrupt.json")
    }
}
