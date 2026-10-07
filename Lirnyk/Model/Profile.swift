import Foundation

nonisolated struct Profile: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var prompt: String

    init(id: UUID = UUID(), title: String, prompt: String) {
        self.id = id
        self.title = title
        self.prompt = prompt
    }
}

enum DefaultProfiles {
    /// Order matters: HotkeyManager assigns ⌃⌥F, ⌃⌥H, ⌃⌥O in this order.
    static func make() -> [Profile] {
        [
            Profile(
                title: "Friendly",
                prompt: "Fix typos and grammar. Make the text more friendly and warm. Emoji are allowed where natural. Keep the original language. Output only the rewritten text."
            ),
            Profile(
                title: "Corporate",
                prompt: "Fix typos and grammar. Be polite and professional, follow corporate communication style. Keep the original language. Output only the rewritten text."
            ),
            Profile(
                title: "Tech",
                prompt: "Rewrite following ASD-STE100 Simplified Technical English. Be concise and direct, no filler. Fix typos. Output only the rewritten text."
            ),
        ]
    }
}
