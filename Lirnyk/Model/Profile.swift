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
                prompt: "Fix typos and grammar. Be polite and professional, follow corporate communication style: rephrase rude, emotional, sarcastic or passive-aggressive wording as neutral, direct business language, and leave wording that is already correct and professional unchanged. Preserve all facts and specific details. Do not add greetings, sign-offs, addressees, requests or claims that are not in the original, and keep its structure and approximate length. Keep the original language. Output only the rewritten text."
            ),
            Profile(
                title: "Tech",
                prompt: "Rewrite following ASD-STE100 Simplified Technical English. Be concise and direct, no filler. Fix typos. Output only the rewritten text."
            ),
        ]
    }

    /// The prompt this version of the app ships for a built-in profile title (Friendly, Corporate, Tech), so
    /// Settings can reset an edited prompt. Nil for the user's own profiles and for renamed built-in ones.
    static func defaultPrompt(forTitle title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return make().first { $0.title == trimmed }?.prompt
    }

    /// The Corporate prompt shipped up to 0.3.x. Replaced by v02 from the prompt-tuning eval (lirnyk.app/blog).
    static let corporateV1 = "Fix typos and grammar. Be polite and professional, follow corporate communication style. Keep the original language. Output only the rewritten text."

    /// Old default prompts and the current ones that replace them. Only a prompt the user never edited matches.
    static var upgrades: [String: String] {
        let corporate = make().first { $0.title == "Corporate" }!.prompt
        return [corporateV1: corporate]
    }

    /// Swaps untouched old default prompts for the current ones; returns nil when nothing changed.
    static func upgrade(_ profiles: [Profile]) -> [Profile]? {
        let table = upgrades
        var changed = false
        let result = profiles.map { profile -> Profile in
            guard let newer = table[profile.prompt] else { return profile }
            changed = true
            var upgraded = profile
            upgraded.prompt = newer
            return upgraded
        }
        return changed ? result : nil
    }
}
