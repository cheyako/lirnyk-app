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
            let tabs = SettingsTabViewController()
            for pane in content().panes {
                let item = NSTabViewItem(viewController: pane.controller)
                item.label = pane.title
                item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.title)
                tabs.addTabViewItem(item)
            }
            let window = NSWindow(contentViewController: tabs)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.toolbarStyle = .preference
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Preferences-style toolbar tabs, titled after the selected pane. Panes share one size, so the window is fitted once.
private final class SettingsTabViewController: NSTabViewController {
    override init(nibName: NSNib.Name?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        tabStyle = .toolbar
        canPropagateSelectedChildViewControllerTitle = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewWillAppear() {
        super.viewWillAppear()
        if let controller = tabViewItems[safe: selectedTabViewItemIndex]?.viewController { fitWindow(to: controller) }
    }

    private func fitWindow(to controller: NSViewController) {
        guard let window = view.window else { return }
        let size = controller.preferredContentSize
        guard size.width > 0, size.height > 0 else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true, animate: window.isVisible)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
