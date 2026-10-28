import KeyboardShortcuts
import SwiftUI

struct MenuContent: View {
    let profiles: ProfileStore
    let permissions: PermissionsService
    let updates: UpdateMonitor
    let runProfile: (Profile) -> Void
    let openSettings: () -> Void

    var body: some View {
        if let update = updates.available {
            Button("Update Available: Lirnyk \(update.version)…") { NSWorkspace.shared.open(update.url) }
            Divider()
        }
        ForEach(profiles.profiles) { profile in
            Button(profile.title.isEmpty ? "Untitled" : profile.title) { runProfile(profile) }
                .globalKeyboardShortcut(.profile(profile.id))
        }
        if profiles.profiles.isEmpty {
            Text("No profiles")
        }
        Divider()
        if !permissions.isTrusted {
            Button("Grant Accessibility Permission…") {
                permissions.requestAccess()
                openSettings()
            }
        }
        Button("Settings…", action: openSettings)
            .keyboardShortcut(",")
        Button("Support Lirnyk…") { NSWorkspace.shared.open(AboutSettingsView.donateURL) }
        Button("Quit Lirnyk") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
