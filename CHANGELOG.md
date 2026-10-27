# Changelog

User-facing changes in each Lirnyk release, newest first. Add entries under **Unreleased** as you work;
`make notes` turns a version's section into GitHub release notes. See [docs/releasing.md](docs/releasing.md).

## Unreleased

## 0.2.0 — 2026-10-27

Lirnyk 0.2.0 adds more AI providers and an update check.

### New
- **Choose your AI provider** in Settings: OpenRouter, OpenAI, Anthropic or Gemini.
  Each provider keeps its own API key (in the Keychain) and model, so you can switch back and forth.
  Existing OpenRouter settings carry over.
- **Version and update check** in Settings → General → About. *Check for Updates* tells you when a newer
  release is on GitHub.

### Fixes
- An unexpected answer from the AI provider is shown as an error instead of "AI returned empty text",
  and nothing is pasted.

## 0.1.0 — 2026-10-07

First public build of Lirnyk, a menu-bar AI rephraser for macOS.
