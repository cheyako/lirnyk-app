import AppKit

enum AppEnvironment {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let didLaunchBeforeKey = "didLaunchBefore"

    let settings = SettingsStore()
    let profiles = ProfileStore()
    let permissions = PermissionsService()
    let appState = AppState()
    private let hud = HUDController()

    lazy var client: OpenRouterClient = OpenRouterClient { [settings] in
        (apiKey: settings.apiKey, model: settings.modelID)
    }

    lazy var coordinator: RephraseCoordinator = {
        let coordinator = RephraseCoordinator(
            selection: ClipboardSelectionService(), client: client, accessibility: permissions,
            focus: WorkspaceFocusTracker(), feedback: hud, cancelKey: EscKeyMonitor(),
            hasAPIKey: { [settings] in settings.hasAPIKey })
        coordinator.openSettings = { [weak self] in self?.openSettings() }
        coordinator.onBusyChanged = { [appState] in appState.setBusy($0) }
        return coordinator
    }()

    private lazy var hotkeys = HotkeyManager(store: profiles) { [weak self] profile in
        self?.run(profile)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppEnvironment.isRunningTests else { return }

        if profiles.load() {
            hotkeys.assignDefaultShortcuts(to: profiles.profiles)
        }
        profiles.onChange = { [weak self] in self?.hotkeys.sync() }
        hotkeys.sync()

        if !UserDefaults.standard.bool(forKey: Self.didLaunchBeforeKey) {
            UserDefaults.standard.set(true, forKey: Self.didLaunchBeforeKey)
            try? LaunchAtLogin.set(true)
        }
        if !permissions.checkTrusted() || !settings.hasAPIKey {
            openSettings()
        }
    }

    /// Runs a profile; `delay` lets the menu close and focus return to the previous app.
    func run(_ profile: Profile, delay: Duration = .zero) {
        Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            await coordinator.run(profile)
        }
    }

    func openSettings() {
        // Replaced by SettingsWindowController in Task 7.
    }
}
