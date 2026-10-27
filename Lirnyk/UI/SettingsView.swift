import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    let settings: SettingsStore
    let profiles: ProfileStore
    let permissions: PermissionsService
    let client: RephraseClient
    let updates: UpdateChecker

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings, permissions: permissions, client: client, updates: updates)
                .tabItem { Label("General", systemImage: "gearshape") }
            ProfilesSettingsView(store: profiles)
                .tabItem { Label("Profiles", systemImage: "text.bubble") }
        }
        .frame(width: 680, height: 480)
    }
}

struct GeneralSettingsView: View {
    @Bindable var settings: SettingsStore
    let permissions: PermissionsService
    let client: RephraseClient
    let updates: UpdateChecker

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var updateStatus: String?
    @State private var updateURL: URL?
    @State private var isCheckingUpdates = false

    var body: some View {
        Form {
            Section("Permissions") {
                if permissions.isTrusted {
                    Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack {
                        Label("Accessibility access is required to read and replace selected text",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Open System Settings") {
                            permissions.requestAccess()
                            permissions.openSystemSettings()
                        }
                    }
                }
            }
            Section("AI provider") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(AIProvider.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: settings.provider) { testResult = nil }
                SecureField("\(settings.provider.displayName) API key", text: $settings.apiKey)
                    .onSubmit { settings.flushAPIKey() }
                TextField("Model", text: $settings.modelID)
                HStack {
                    Link("Get API key", destination: settings.provider.apiKeysURL)
                    Link("Browse models", destination: settings.provider.modelsURL)
                    Spacer()
                    if let testResult {
                        Text(testResult).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Button("Test connection", action: testConnection)
                        .disabled(isTesting || !settings.hasAPIKey)
                }
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        settings.launchAtLoginWanted = enabled
                        do { try LaunchAtLogin.set(enabled) } catch { launchAtLogin = LaunchAtLogin.isEnabled }
                    }
            }
            Section("About") {
                LabeledContent("Version", value: "\(UpdateChecker.currentVersion) (\(UpdateChecker.currentBuild))")
                HStack {
                    if let updateURL {
                        Link(updateStatus ?? "Download", destination: updateURL)
                    } else if let updateStatus {
                        Text(updateStatus).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    Button("Check for Updates", action: checkForUpdates)
                        .disabled(isCheckingUpdates)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            while !Task.isCancelled {
                permissions.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func checkForUpdates() {
        isCheckingUpdates = true
        updateURL = nil
        updateStatus = "Checking…"
        Task {
            defer { isCheckingUpdates = false }
            do {
                switch try await updates.check() {
                case .upToDate:
                    updateStatus = "✓ Lirnyk is up to date"
                case let .available(version, url):
                    updateStatus = "Lirnyk \(version) is available — Download"
                    updateURL = url
                }
            } catch {
                updateStatus = "✗ " + ((error as? UpdateCheckError)?.message ?? error.localizedDescription)
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = "Testing…"
        Task {
            defer { isTesting = false }
            do {
                settings.flushAPIKey()
                let reply = try await client.rephrase(text: "ping", systemPrompt: "Reply with the single word OK.")
                testResult = "✓ \(reply.prefix(40))"
            } catch {
                testResult = "✗ " + ((error as? RephraseError)?.message ?? error.localizedDescription)
            }
        }
    }
}

struct ProfilesSettingsView: View {
    let store: ProfileStore
    @State private var selection: Profile.ID?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(store.profiles) { profile in
                        Text(profile.title.isEmpty ? "Untitled" : profile.title).tag(profile.id)
                    }
                }
                Divider()
                HStack(spacing: 4) {
                    Button { selection = store.add().id } label: { Image(systemName: "plus") }
                    Button {
                        guard let selection else { return }
                        store.delete(id: selection)
                        self.selection = store.profiles.first?.id
                    } label: { Image(systemName: "minus") }
                        .disabled(selection == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
            .frame(width: 190)

            Divider()

            if let id = selection, let profile = store.profiles.first(where: { $0.id == id }) {
                ProfileEditor(profile: profile, onChange: store.update)
                    .id(id)
            } else {
                ContentUnavailableView("No Profile Selected", systemImage: "text.bubble")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { selection = selection ?? store.profiles.first?.id }
    }
}

struct ProfileEditor: View {
    @State private var profile: Profile
    let onChange: (Profile) -> Void

    init(profile: Profile, onChange: @escaping (Profile) -> Void) {
        _profile = State(initialValue: profile)
        self.onChange = onChange
    }

    var body: some View {
        Form {
            TextField("Title", text: $profile.title)
            LabeledContent("Shortcut") {
                KeyboardShortcuts.Recorder(for: .profile(profile.id))
            }
            Section("Prompt (sent as the system prompt)") {
                TextEditor(text: $profile.prompt)
                    .font(.body)
                    .frame(minHeight: 220)
            }
        }
        .formStyle(.grouped)
        .onChange(of: profile) { _, updated in onChange(updated) }
    }
}
