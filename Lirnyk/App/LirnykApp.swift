import SwiftUI

@main
struct LirnykApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Lirnyk", systemImage: "text.bubble") {
            Button("Quit Lirnyk") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
