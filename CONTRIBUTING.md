# Contributing to Lirnyk

Thanks for helping! Lirnyk is a small project with one maintainer, so here is what works best.

## Bug reports and ideas

Open an [issue](https://github.com/cheyako/lirnyk-app/issues). For a bug, include:
- your macOS version and the Lirnyk version (Settings → About);
- the AI provider and model;
- the app you were rewriting text in;
- what you expected and what happened instead.

Never paste API keys into an issue.

## Pull requests

**Small fixes are welcome without any paperwork:** typos, documentation, translations of a few strings, and bug
fixes of a few lines.

**Larger changes need a Contributor License Agreement (CLA).** This includes new features, refactoring and anything
over a few dozen lines.
- When you open the pull request, a bot asks you to sign the CLA with one click.
- You keep the copyright to your code. The CLA lets the project relicense the code later. Lirnyk itself stays free
  software.
- If you'd rather not sign, please open an issue describing the change instead, and it may be implemented separately.

Before starting on something big, open an issue first, so we can agree on the approach.

## Development

See the [README](README.md#build--run) for building and running. Before sending a pull request:
- run `make test` and make sure it passes;
- add or update tests for the behaviour you change;
- for user-facing changes, add a line under *Unreleased* in [CHANGELOG.md](CHANGELOG.md);
- keep the style of the surrounding code.

## Name and icon

The Lirnyk name and icon are not covered by the license. If you publish a fork or a modified build, give it a
different name and icon.
