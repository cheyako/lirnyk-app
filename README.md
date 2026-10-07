# Lirnyk

macOS menu-bar app that rephrases the selected text in any app with AI (via [OpenRouter](https://openrouter.ai)).
Select text, press a profile hotkey, and the selection is replaced with the rewritten text. ⌘Z undoes it.

## How it works

1. You press a profile's global hotkey (for example ⌃⌥F) while text is selected.
2. Lirnyk saves your clipboard, sends ⌘C, and reads the selection from the pasteboard.
3. It sends the text to OpenRouter. The profile's prompt is the system prompt and the selected text is the user message.
4. When the answer arrives, Lirnyk returns focus to the original app if needed, pastes the result with ⌘V,
   and restores your clipboard. The selection's leading and trailing whitespace is kept.

While a request runs, the menu-bar icon pulses and a small HUD near the cursor shows progress. Press **Esc** to cancel.
If something goes wrong (nothing selected, missing API key, HTTP error, truncated or empty answer),
the HUD shows the error, nothing is pasted, and your clipboard is restored.

The app has no Dock icon. It starts at login by default.

## Requirements
- macOS 14+
- Xcode 26, XcodeGen (`brew install xcodegen`)
- An OpenRouter API key

## Build & run
    make test      # unit tests
    make build     # Debug build
    make install   # Release build → /Applications/Lirnyk.app and launch
    make clean     # remove build/ and the generated Xcode project

`Lirnyk.xcodeproj` is generated from `project.yml`. Every make target regenerates it, so edit `project.yml`, not the project.

On first launch grant **Accessibility** (System Settings → Privacy & Security → Accessibility),
then enter your OpenRouter API key in Settings.

## Settings
- **General**: Accessibility status, OpenRouter API key (stored in the Keychain), model ID
  (one model for all profiles, default `openai/gpt-4o-mini`), launch at login, and *Test connection*.
- **Profiles**: add, remove and edit profiles.

## Profiles
Each profile has a title, a global shortcut and a prompt. The prompt is sent as the system
prompt and the selected text as the user message. The prompt controls everything, including the output language.
Defaults: Friendly ⌃⌥F, Corporate ⌃⌥H, Tech ⌃⌥O.

Profiles are stored in `~/Library/Application Support/Lirnyk/profiles.json`. You can also run a profile from the menu-bar menu.

## Project layout
```
Lirnyk/
  App/          entry point, AppDelegate (dependency wiring), AppState (busy flag, icon animation)
  Model/        Profile, ProfileStore (JSON), SettingsStore (UserDefaults + Keychain), Keychain
  Services/     OpenRouterClient, clipboard SelectionService, KeyEventPoster (⌘C/⌘V),
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
