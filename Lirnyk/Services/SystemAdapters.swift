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

    /// Asks the app to come forward and waits up to 1 s for it; activation is cooperative and may be declined.
    func activate(pid: pid_t) async {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        NSApp.yieldActivation(to: app)
        app.activate()
        for _ in 0..<50 where frontmostAppID() != pid {
            try? await Task.sleep(for: .milliseconds(20))
        }
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

    /// Register only a stable install: not a mounted DMG, a translocated copy, or a dev build.
    static func shouldRegister(wanted: Bool, isEnabled: Bool, bundlePath: String) -> Bool {
        guard wanted, !isEnabled else { return false }
        let transientLocations = ["/Volumes/", "/AppTranslocation/", "/DerivedData/"]
        return !transientLocations.contains { bundlePath.contains($0) }
    }

    /// Called on every launch so a failed or stale registration is retried.
    static func syncOnLaunch(wanted: Bool) {
        guard shouldRegister(wanted: wanted, isEnabled: isEnabled, bundlePath: Bundle.main.bundlePath) else { return }
        try? set(true)
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
