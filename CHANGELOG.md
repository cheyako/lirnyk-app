# Changelog

User-facing changes in each Lirnyk release, newest first. Add entries under **Unreleased** as you work;
`make notes` turns a version's section into GitHub release notes. See [docs/releasing.md](docs/releasing.md).

## Unreleased

### New
- **Ollama support**: choose *Ollama (local)* to rewrite text with a model running on your Mac. No API key needed.
  The model list shows what you've pulled; the server address can point to another machine on your network.
- **Redesigned Settings** with General, Profiles and About tabs. Accessibility only appears when it needs attention.
- **Pick a model from a list** of suggested models for each provider, or type a custom one.
- **Show or hide the API key** while you type it.
- **Try a profile in Settings**: paste sample text under the prompt and see the rewrite straight away.
- **Automatic update checks** once a day. A newer release shows in the menu bar menu and in About;
  turn it off in About. These daily checks go to lirnyk.app, which counts them anonymously (only the app and macOS
  version are sent; see the [privacy page](https://lirnyk.app/privacy)).
- **Support Lirnyk** on Ko-fi from Settings → About or the menu-bar menu.

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
