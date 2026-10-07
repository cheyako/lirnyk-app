import AppKit
import ApplicationServices
import Observation
import ServiceManagement

@Observable
final class PermissionsService: AccessibilityChecking {
    private(set) var isTrusted = AXIsProcessTrusted()

    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
    }

    func checkTrusted() -> Bool {
        refresh()
        return isTrusted
    }

    /// Shows the system "grant Accessibility" prompt (once per launch, by macOS rules).
    func requestAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

final class WorkspaceFocusTracker: FocusTracking {
    func frontmostAppID() -> pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    func activate(pid: pid_t) async {
        NSRunningApplication(processIdentifier: pid)?.activate()
        try? await Task.sleep(for: .milliseconds(200))
    }
}

final class EscKeyMonitor: CancelKeyMonitoring {
    private static let escapeKeyCode: UInt16 = 53
    private var monitors: [Any] = []

    func start(onCancel: @escaping () -> Void) {
        stop()
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { event in
            if event.keyCode == Self.escapeKeyCode { onCancel() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            if event.keyCode == Self.escapeKeyCode { onCancel() }
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
