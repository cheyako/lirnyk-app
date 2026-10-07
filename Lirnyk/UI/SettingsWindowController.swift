import AppKit
import SwiftUI

/// Owns the Settings window. (SwiftUI's Settings scene can't be opened programmatically on macOS 14.)
final class SettingsWindowController {
    private let content: () -> SettingsView
    private var window: NSWindow?

    init(content: @escaping () -> SettingsView) {
        self.content = content
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
            window.title = "Lirnyk Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
