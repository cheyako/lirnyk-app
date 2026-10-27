# Lirnyk

macOS menu-bar app that rephrases the selected text in any app with AI: [OpenRouter](https://openrouter.ai), OpenAI, Anthropic or Gemini.
Select text, press a profile hotkey, and the selection is replaced with the rewritten text. ⌘Z undoes it.

## How it works

1. You press a profile's global hotkey (for example ⌃⌥F) while text is selected.
2. Lirnyk saves your clipboard, sends ⌘C, and reads the selection from the pasteboard.
3. It sends the text to the selected AI provider. The profile's prompt is the system prompt and the selected text is the user message.
4. When the answer arrives, Lirnyk returns focus to the original app if needed, pastes the result with ⌘V,
   and restores your clipboard. The selection's leading and trailing whitespace is kept.

While a request runs, the menu-bar icon pulses and a small HUD near the cursor shows progress. Press **Esc** to cancel.
If something goes wrong (nothing selected, missing API key, HTTP error, truncated or empty answer),
the HUD shows the error, nothing is pasted, and your clipboard is restored.

The app has no Dock icon. It starts at login by default.

## Requirements
- macOS 14+
- Xcode 26, XcodeGen (`brew install xcodegen`)
- An API key for OpenRouter, OpenAI, Anthropic or Gemini

## Build & run
    make test      # unit tests
    make build     # Debug build
    make install   # Release build → /Applications/Lirnyk.app and launch
    make clean     # remove build/ and the generated Xcode project

`Lirnyk.xcodeproj` is generated from `project.yml`. Every make target regenerates it, so edit `project.yml`, not the project.

On first launch grant **Accessibility** (System Settings → Privacy & Security → Accessibility),
then pick a provider and enter its API key in Settings.

## Settings
- **General**: Accessibility status, AI provider (OpenRouter, OpenAI, Anthropic or Gemini), the provider's
  API key (stored in the Keychain) and model ID (one model for all profiles), launch at login, and *Test connection*.
  Each provider keeps its own key and model, so switching back and forth loses nothing.
  Default models: OpenRouter `openai/gpt-4o-mini`, OpenAI `gpt-4.1-mini`, Anthropic `claude-haiku-5-5`, Gemini `gemini-2.5-flash`.
- **Profiles**: add, remove and edit profiles.
- **About** (in General): the installed version and *Check for Updates*, which compares it with the latest
  [GitHub release](https://github.com/cheyako/lirnyk-app/releases) and links to the download when a newer one exists.

## Versioning
The version lives in `project.yml`: `MARKETING_VERSION` (shown in Settings, used for the DMG name and the `vX.Y.Z`
release tag) and `CURRENT_PROJECT_VERSION` (build number, bumped with every release).
To release: bump both, commit, `make release`, then publish a GitHub release tagged `vX.Y.Z` with the DMG.
*Check for Updates* only sees full (non-prerelease) releases.

## Profiles
Each profile has a title, a global shortcut and a prompt. The prompt is sent as the system
prompt and the selected text as the user message. The prompt controls everything, including the output language.
Defaults: Friendly ⌃⌥F, Corporate ⌃⌥H, Tech ⌃⌥O.

Profiles are stored in `~/Library/Application Support/Lirnyk/profiles.json`. You can also run a profile from the menu-bar menu.

## Project layout
```
Lirnyk/
  App/          entry point, AppDelegate (dependency wiring), AppState (busy flag, icon animation)
  Model/        Profile, AIProvider, ProfileStore (JSON), SettingsStore (UserDefaults + Keychain), Keychain
  Services/     AIClient (all providers), clipboard SelectionService, KeyEventPoster (⌘C/⌘V),
                HotkeyManager, PasteboardSnapshot, errors, whitespace helpers
  Coordinator/  RephraseCoordinator — runs one rephrase job, handles cancel and errors
  UI/           menu, HUD panel, Settings window, menu-bar icon
LirnykTests/    Swift Testing unit tests with fakes for the system and network
scripts/        release.sh (notarized DMG) and its tests
docs/           manual test checklist, design spec and implementation plan
```

Global shortcuts use [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts).
The design is described in [docs/superpowers/specs/2026-10-07-lirnyk-design.md](docs/superpowers/specs/2026-10-07-lirnyk-design.md).
Before a release, run the manual checklist in [docs/manual-test.md](docs/manual-test.md).

## Release (notarized DMG)
One-time:
1. Create a *Developer ID Application* certificate (Xcode → Settings → Accounts → Manage Certificates).
2. `xcrun notarytool store-credentials lirnyk-notary --apple-id <apple-id> --team-id 2S5U65Y5CZ`
   (use an app-specific password).

Then: `make release` → `build/release/Lirnyk-<version>.dmg`.
The script picks the single valid *Developer ID Application* certificate for team 2S5U65Y5CZ; if you have
several, set `SIGN_IDENTITY=<SHA-1>`. A rejected notarization prints Apple's log and stops.
Bump `MARKETING_VERSION` in `project.yml` per release.
Stapling downloads Apple's ticket over a pinned connection: it fails ("Certificate authority pinning
mismatch", error 68) behind HTTPS-inspecting corporate VPNs/proxies. Disconnect them before `make release`.

## Quick DMG (not notarized)
`make dmg` → `build/dmg/Lirnyk-<version>-unnotarized.dmg` in about a minute: Developer ID signed, but not sent
to Apple. Fine for your own Macs; others must allow it via System Settings → Privacy & Security → *Open Anyway*.
