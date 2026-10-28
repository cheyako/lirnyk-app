import KeyboardShortcuts
import SwiftUI

struct SettingsView {
    let settings: SettingsStore
    let profiles: ProfileStore
    let permissions: PermissionsService
    let client: RephraseClient
    let updates: UpdateMonitor

    /// Every pane shares one size so the window doesn't jump when switching tabs.
    static let paneSize = CGSize(width: 660, height: 460)

    struct Pane {
        let title: String
        let symbol: String
        let controller: NSViewController
    }

    var panes: [Pane] {
        [
            pane("General", symbol: "gearshape", GeneralSettingsView(settings: settings, permissions: permissions, client: client)),
            pane("Profiles", symbol: "text.bubble", ProfilesSettingsView(store: profiles, client: client)),
            pane("About", symbol: "info.circle", AboutSettingsView(updates: updates)),
        ]
    }

    private func pane(_ title: String, symbol: String, _ view: some View) -> Pane {
        let controller = NSHostingController(rootView: view.frame(width: Self.paneSize.width, height: Self.paneSize.height))
        controller.sizingOptions = [.preferredContentSize]
        controller.title = title
        return Pane(title: title, symbol: symbol, controller: controller)
    }
}

private struct SettingsForm<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form { content }
            .formStyle(.grouped)
    }
}

/// Row label with a coloured icon tile, as in System Settings.
struct SettingsLabel: View {
    let title: String
    let symbol: String
    let color: Color

    init(_ title: String, symbol: String, color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
}

/// Outcome of a one-off action such as a connection test or an update check.
enum StatusMessage: Equatable {
    case progress(String)
    case success(String)
    case failure(String)
}

struct StatusView: View {
    let status: StatusMessage

    var body: some View {
        switch status {
        case let .progress(text):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(text)
            }
            .foregroundStyle(.secondary)
        case let .success(text):
            Label(text, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .failure(text):
            Label(text, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}

struct GeneralSettingsView: View {
    @Bindable var settings: SettingsStore
    let permissions: PermissionsService
    let client: RephraseClient

    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        SettingsForm {
            if !permissions.isTrusted {
                Section {
                    LabeledContent {
                        Button("Open System Settings") {
                            permissions.requestAccess()
                            permissions.openSystemSettings()
                        }
                    } label: {
                        SettingsLabel("Accessibility access needed", symbol: "hand.raised.fill", color: .orange)
                        Text("Lirnyk reads and replaces the selected text through Accessibility.")
                    }
                }
            }
            AISettingsSections(settings: settings, client: client)
            Section {
                Toggle(isOn: $launchAtLogin) {
                    SettingsLabel("Launch at login", symbol: "power", color: .green)
                }
                .onChange(of: launchAtLogin) { _, enabled in
                    settings.launchAtLoginWanted = enabled
                    do { try LaunchAtLogin.set(enabled) } catch { launchAtLogin = LaunchAtLogin.isEnabled }
                }
            }
        }
        .animation(.default, value: permissions.isTrusted)
        .task {
            while !Task.isCancelled {
                permissions.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

/// Provider, key, model and connection test; shown as sections of the General pane.
struct AISettingsSections: View {
    @Bindable var settings: SettingsStore
    let client: RephraseClient

    @State private var testStatus: StatusMessage?
    @State private var showsAPIKey = false
    @State private var usesCustomModel = false
    /// Models installed on the Ollama server; nil until loaded.
    @State private var ollamaModels: [String]?
    @State private var ollamaError: String?

    private static let customModelTag = "\u{0}custom"

    /// Picker selection: a suggested model ID, or `customModelTag` while a typed-in ID is in use.
    private var modelChoice: Binding<String> {
        Binding {
            usesCustomModel ? Self.customModelTag : settings.modelID
        } set: { choice in
            usesCustomModel = choice == Self.customModelTag
            if !usesCustomModel { settings.modelID = choice }
        }
    }

    private var modelOptions: [String] {
        settings.provider == .ollama ? ollamaModels ?? [] : settings.provider.suggestedModelIDs
    }

    var body: some View {
        Group {
            Section {
                Picker(selection: $settings.provider) {
                    ForEach(AIProvider.allCases) { Text($0.displayName).tag($0) }
                } label: {
                    SettingsLabel("Provider", symbol: "sparkles", color: .purple)
                }
                .onChange(of: settings.provider) {
                    testStatus = nil
                    syncCustomModel()
                }
                if settings.provider.requiresAPIKey {
                    apiKeyRow
                } else {
                    TextField(text: $settings.ollamaServer, prompt: Text(AIProvider.defaultOllamaServer)) {
                        SettingsLabel("Server", symbol: "server.rack", color: .gray)
                    }
                }
                Picker(selection: modelChoice) {
                    ForEach(modelOptions, id: \.self) { Text($0).tag($0) }
                    if !modelOptions.isEmpty { Divider() }
                    Text("Custom…").tag(Self.customModelTag)
                } label: {
                    SettingsLabel("Model", symbol: "cpu", color: .blue)
                    if settings.provider == .ollama, let ollamaError {
                        Text(ollamaError).foregroundStyle(.red)
                    }
                }
                if usesCustomModel {
                    TextField(text: $settings.modelID, prompt: Text("Model ID")) {
                        Text("Model ID").padding(.leading, 28)
                    }
                }
            } footer: {
                HStack {
                    if settings.provider.requiresAPIKey {
                        Link("Get API key", destination: settings.provider.apiKeysURL)
                    } else {
                        Link("Download Ollama", destination: settings.provider.apiKeysURL)
                    }
                    Link("Browse models", destination: settings.provider.modelsURL)
                    Spacer()
                    if settings.provider.requiresAPIKey {
                        Label("Stored in your Keychain", systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Runs on your Mac, no key needed", systemImage: "desktopcomputer")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
            }
            Section {
                LabeledContent {
                    Button("Test", action: testConnection)
                        .disabled(testStatus == .progress("Testing…") || !settings.isConfigured)
                } label: {
                    SettingsLabel("Connection", symbol: "bolt.horizontal.fill", color: .teal)
                    if let testStatus {
                        StatusView(status: testStatus)
                    } else if !settings.isConfigured {
                        Text("Add an API key to test the connection.")
                    }
                }
            }
        }
        .onAppear(perform: syncCustomModel)
        .task(id: "\(settings.provider.rawValue) \(settings.ollamaServer)") { await loadOllamaModels() }
    }

    private var apiKeyRow: some View {
        LabeledContent {
            HStack(spacing: 6) {
                let prompt = Text("Paste your \(settings.provider.displayName) key")
                Group {
                    if showsAPIKey {
                        TextField("API key", text: $settings.apiKey, prompt: prompt)
                    } else {
                        SecureField("API key", text: $settings.apiKey, prompt: prompt)
                    }
                }
                .labelsHidden()
                .frame(width: 240)
                .onSubmit { settings.flushAPIKey() }
                Button {
                    showsAPIKey.toggle()
                } label: {
                    Image(systemName: showsAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(showsAPIKey ? "Hide key" : "Show key")
            }
        } label: {
            SettingsLabel("API key", symbol: "key.fill", color: .orange)
        }
    }

    /// Reads the installed models whenever Ollama is selected or its address changes (debounced while typing).
    private func loadOllamaModels() async {
        guard settings.provider == .ollama else { return }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        do {
            let models = try await OllamaModels.installed(server: settings.ollamaServer)
            guard !Task.isCancelled else { return }
            ollamaModels = models
            ollamaError = nil
        } catch {
            guard !Task.isCancelled else { return }
            ollamaModels = nil
            ollamaError = (error as? RephraseError)?.message ?? error.localizedDescription
        }
        syncCustomModel()
    }

    private func testConnection() {
        testStatus = .progress("Testing…")
        Task {
            do {
                settings.flushAPIKey()
                let reply = try await client.rephrase(text: "ping", systemPrompt: "Reply with the single word OK.")
                testStatus = .success("Connected · \(reply.prefix(40))")
            } catch {
                testStatus = .failure((error as? RephraseError)?.message ?? error.localizedDescription)
            }
        }
    }

    private func syncCustomModel() {
        usesCustomModel = !modelOptions.contains(settings.modelID)
    }
}

struct AboutSettingsView: View {
    @Bindable var updates: UpdateMonitor

    private static let repositoryURL = URL(string: "https://github.com/cheyako/lirnyk-app")!
    private static let changelogURL = URL(string: "https://github.com/cheyako/lirnyk-app/blob/main/CHANGELOG.md")!
    static let donateURL = URL(string: "https://ko-fi.com/cheyako")!

    @State private var updateStatus: StatusMessage?

    var body: some View {
        SettingsForm {
            Section {
                VStack(spacing: 6) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 96, height: 96)
                    Text("Lirnyk")
                        .font(.title.weight(.semibold))
                    Text("Version \(UpdateChecker.currentVersion) (\(UpdateChecker.currentBuild))")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section {
                LabeledContent {
                    if let update = updates.available {
                        Link("Download", destination: update.url)
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Check for Updates", action: checkForUpdates)
                            .disabled(updateStatus == .progress("Checking…"))
                    }
                } label: {
                    SettingsLabel("Updates", symbol: "arrow.down.circle.fill", color: .blue)
                    if let updateStatus {
                        StatusView(status: updateStatus)
                    } else if let update = updates.available {
                        StatusView(status: .success("Lirnyk \(update.version) is available"))
                    }
                }
                Toggle(isOn: $updates.checksAutomatically) {
                    SettingsLabel("Check automatically", symbol: "clock.arrow.circlepath", color: .green)
                    Text("Once a day, quietly. Nothing is installed without you.")
                }
                Link(destination: Self.changelogURL) {
                    SettingsLabel("What's new", symbol: "list.bullet.rectangle.fill", color: .indigo)
                }
                Link(destination: Self.repositoryURL) {
                    SettingsLabel("Source on GitHub", symbol: "chevron.left.forwardslash.chevron.right", color: .gray)
                }
            }
            Section {
                LabeledContent {
                    Link("Support on Ko-fi", destination: Self.donateURL)
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                } label: {
                    SettingsLabel("Support Lirnyk", symbol: "heart.fill", color: .pink)
                    Text("Lirnyk is free and open source. A coffee helps keep it going.")
                }
            }
        }
    }

    private func checkForUpdates() {
        updateStatus = .progress("Checking…")
        Task {
            do {
                switch try await updates.check() {
                case .upToDate:
                    updateStatus = .success("Lirnyk is up to date")
                case let .available(version, _):
                    updateStatus = .success("Lirnyk \(version) is available")
                }
            } catch {
                updateStatus = .failure((error as? UpdateCheckError)?.message ?? error.localizedDescription)
            }
        }
    }
}

struct ProfilesSettingsView: View {
    let store: ProfileStore
    let client: RephraseClient
    @State private var selection: Profile.ID?
    /// Kept here so the sample survives switching between profiles.
    @State private var sampleText = ""
    /// Bumped when a shortcut is recorded, so the list re-reads shortcuts it can't observe.
    @State private var shortcutRevision = 0

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(store.profiles) { profile in
                        HStack {
                            Text(profile.title.isEmpty ? "Untitled" : profile.title)
                                .lineLimit(1)
                            Spacer()
                            if let shortcut = KeyboardShortcuts.getShortcut(for: .profile(profile.id)) {
                                Text(shortcut.description)
                                    .font(.callout.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(profile.id)
                    }
                }
                .listStyle(.sidebar)
                // Outside a split view the sidebar material is a flat grey slab; use the window background instead.
                .scrollContentBackground(.hidden)
                .id(shortcutRevision)
                Divider()
                HStack(spacing: 2) {
                    Button { selection = store.add().id } label: {
                        Image(systemName: "plus").frame(width: 20, height: 20)
                    }
                    .help("Add profile")
                    Button {
                        guard let selection else { return }
                        store.delete(id: selection)
                        self.selection = store.profiles.first?.id
                    } label: {
                        Image(systemName: "minus").frame(width: 20, height: 20)
                    }
                    .help("Delete profile")
                    .disabled(selection == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(6)
            }
            .frame(width: 210)

            Divider()

            if let id = selection, let profile = store.profiles.first(where: { $0.id == id }) {
                ProfileEditor(profile: profile, client: client, sampleText: $sampleText, onChange: store.update) {
                    shortcutRevision += 1
                }
                .id(id)
            } else {
                ContentUnavailableView {
                    Label("No Profile Selected", systemImage: "text.bubble")
                } description: {
                    Text("Pick a profile on the left, or add one with +.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { selection = selection ?? store.profiles.first?.id }
    }
}

struct ProfileEditor: View {
    @State private var profile: Profile
    let client: RephraseClient
    @Binding var sampleText: String
    let onChange: (Profile) -> Void
    let onShortcutChange: () -> Void

    @State private var tryResult: String?
    @State private var tryStatus: StatusMessage?

    init(profile: Profile, client: RephraseClient, sampleText: Binding<String>,
         onChange: @escaping (Profile) -> Void, onShortcutChange: @escaping () -> Void) {
        _profile = State(initialValue: profile)
        self.client = client
        _sampleText = sampleText
        self.onChange = onChange
        self.onShortcutChange = onShortcutChange
    }

    var body: some View {
        Form {
            Section {
                TextField(text: $profile.title, prompt: Text("Profile name")) {
                    SettingsLabel("Title", symbol: "textformat", color: .blue)
                }
                LabeledContent {
                    KeyboardShortcuts.Recorder(for: .profile(profile.id)) { _ in onShortcutChange() }
                } label: {
                    SettingsLabel("Shortcut", symbol: "command", color: .gray)
                }
            }
            Section {
                TextEditor(text: $profile.prompt)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
            } header: {
                Text("Prompt")
            } footer: {
                Text("Sent to the model as the system prompt, followed by your selected text.")
            }
            Section {
                TextEditor(text: $sampleText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60)
                    .overlay(alignment: .topLeading) {
                        if sampleText.isEmpty {
                            Text("Paste sample text…")
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                LabeledContent {
                    Button("Rewrite", action: tryProfile)
                        .disabled(tryStatus == .progress("Rewriting…")
                            || sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } label: {
                    if let tryStatus { StatusView(status: tryStatus) }
                }
                if let tryResult {
                    Text(tryResult)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } header: {
                Text("Try it")
            }
        }
        .formStyle(.grouped)
        .onChange(of: profile) { _, updated in onChange(updated) }
    }

    private func tryProfile() {
        tryStatus = .progress("Rewriting…")
        tryResult = nil
        Task {
            do {
                tryResult = try await client.rephrase(text: sampleText, systemPrompt: profile.prompt)
                tryStatus = nil
            } catch {
                tryStatus = .failure((error as? RephraseError)?.message ?? error.localizedDescription)
            }
        }
    }
}
