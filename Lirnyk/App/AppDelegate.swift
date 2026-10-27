import AppKit

enum AppEnvironment {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()
    let profiles = ProfileStore()
    let permissions = PermissionsService()
    let appState = AppState()
    private let hud = HUDController()
    let updates: UpdateMonitor = {
        let checker = UpdateChecker()
        return UpdateMonitor { try await checker.check() }
    }()

    lazy var client: AIClient = AIClient { [settings] in
        (provider: settings.provider, apiKey: settings.apiKey, model: settings.modelID, server: settings.ollamaServer)
    }

    lazy var coordinator: RephraseCoordinator = {
        let coordinator = RephraseCoordinator(
            selection: ClipboardSelectionService(), client: client, accessibility: permissions,
            focus: WorkspaceFocusTracker(), feedback: hud, cancelKey: EscKeyMonitor(),
            hasAPIKey: { [settings] in settings.isConfigured })
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

        LaunchAtLogin.syncOnLaunch(wanted: settings.launchAtLoginWanted)
        updates.start()
        if !permissions.checkTrusted() || !settings.isConfigured {
            openSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        settings.flushAPIKey()
    }

    /// Runs a profile; `delay` lets the menu close and focus return to the previous app.
    func run(_ profile: Profile, delay: Duration = .zero) {
        Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            await coordinator.run(profile)
        }
    }

    private lazy var settingsWindow = SettingsWindowController { [unowned self] in
        SettingsView(settings: settings, profiles: profiles, permissions: permissions, client: client, updates: updates)
    }

    func openSettings() {
        settingsWindow.show()
    }
}
