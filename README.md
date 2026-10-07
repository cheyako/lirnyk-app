# Lirnyk

macOS menu-bar app that rephrases the selected text in any app with AI (OpenRouter).
Select text, press a profile hotkey, and the selection is replaced. ⌘Z undoes it.

## Requirements
- macOS 14+
- Xcode 26, XcodeGen (`brew install xcodegen`)
- An OpenRouter API key

## Build & run
    make test      # unit tests
    make install   # Release build → /Applications/Lirnyk.app and launch

On first launch grant **Accessibility** (System Settings → Privacy & Security → Accessibility),
then enter your OpenRouter API key in Settings.

## Profiles
Each profile has a title, a global shortcut and a prompt. The prompt is sent as the system
prompt and the selected text as the user message. Defaults: Friendly ⌃⌥F, Corporate ⌃⌥H, Tech ⌃⌥O.

## Release (notarized DMG)
One-time:
1. Create a *Developer ID Application* certificate (Xcode → Settings → Accounts → Manage Certificates).
2. `xcrun notarytool store-credentials lirnyk-notary --apple-id <apple-id> --team-id 2S5U65Y5CZ`
   (use an app-specific password).

Then: `make release` → `build/release/Lirnyk-<version>.dmg`.
The script picks the single valid *Developer ID Application* certificate for team 2S5U65Y5CZ; if you have
several, set `SIGN_IDENTITY=<SHA-1>`. A rejected notarization prints Apple's log and stops.
Bump `MARKETING_VERSION` in `project.yml` per release.
