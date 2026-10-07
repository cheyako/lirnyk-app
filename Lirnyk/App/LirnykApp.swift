import SwiftUI

@main
struct LirnykApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(
                profiles: appDelegate.profiles,
                permissions: appDelegate.permissions,
                runProfile: { appDelegate.run($0, delay: .milliseconds(300)) },
                openSettings: { appDelegate.openSettings() })
        } label: {
            Image(systemName: appDelegate.appState.iconPulse ? "text.bubble.fill" : "text.bubble")
        }
    }
}
