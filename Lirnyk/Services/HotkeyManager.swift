import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Shortcut storage name for a profile. Must not contain dots.
    static func profile(_ id: UUID) -> Self {
        Self("profile_\(id.uuidString)")
    }
}

final class HotkeyManager {
    private let store: ProfileStore
    private let onTrigger: (Profile) -> Void
    private var registered: Set<UUID> = []

    init(store: ProfileStore, onTrigger: @escaping (Profile) -> Void) {
        self.store = store
        self.onTrigger = onTrigger
    }

    /// Registers handlers for new profiles and removes shortcuts of deleted ones.
    func sync() {
        let current = Set(store.profiles.map(\.id))
        for id in registered.subtracting(current) {
            KeyboardShortcuts.removeHandler(for: .profile(id))
            KeyboardShortcuts.setShortcut(nil, for: .profile(id))
        }
        for id in current.subtracting(registered) {
            KeyboardShortcuts.onKeyUp(for: .profile(id)) { [weak self] in
                guard let self, let profile = store.profiles.first(where: { $0.id == id }) else { return }
                onTrigger(profile)
            }
        }
        registered = current
    }

    /// ⌃⌥F, ⌃⌥H, ⌃⌥O for the seeded Friendly, Corporate, Tech profiles.
    func assignDefaultShortcuts(to profiles: [Profile]) {
        let shortcuts: [KeyboardShortcuts.Shortcut] = [
            .init(.f, modifiers: [.control, .option]),
            .init(.h, modifiers: [.control, .option]),
            .init(.o, modifiers: [.control, .option]),
        ]
        for (profile, shortcut) in zip(profiles, shortcuts) {
            KeyboardShortcuts.setShortcut(shortcut, for: .profile(profile.id))
        }
    }
}
