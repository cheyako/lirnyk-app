# Releasing a new version

Lirnyk is distributed as a notarized DMG attached to a GitHub release of
[cheyako/lirnyk-app](https://github.com/cheyako/lirnyk-app/releases). _Check for Updates_ in Settings
compares the installed version with the tag of the latest full release, so the tag and the version must match.

## Choosing the number

`MARKETING_VERSION` follows `MAJOR.MINOR.PATCH`:

| Change                             | Example       |
| ---------------------------------- | ------------- |
| Fixes only                         | 0.2.0 → 0.2.1 |
| New features                       | 0.2.1 → 0.3.0 |
| Stable / breaking behaviour change | 0.9.0 → 1.0.0 |

`CURRENT_PROJECT_VERSION` is the build number: add 1 on every release, never reset it.

## 1. Bump the version and finish the changelog

1. In `project.yml`, set the new `MARKETING_VERSION` and increase `CURRENT_PROJECT_VERSION`:
   ```yaml
   MARKETING_VERSION: "0.3.0"
   CURRENT_PROJECT_VERSION: "3"
   ```
2. In `CHANGELOG.md`, rename `## Unreleased` to `## 0.3.0 — YYYY-MM-DD` (today's date) and add a new empty
   `## Unreleased` above it. Write entries for users, not developers: start with a one-line summary, then
   `### New` / `### Fixes` lists. `git log v<previous>..HEAD --oneline` shows what changed.
   The `### Install` part and SHA-256 are added automatically in step 3 — don't write them.

## 2. Test and commit

```
make test
make test-release
git add project.yml CHANGELOG.md
git commit -m "Release 0.3.0: <summary>"
```

## 3. Build the notarized DMG and the release notes

**Turn the VPN off first** — behind its HTTPS inspection `stapler` fails (error 68).

```
make release
```

This refuses to start if `CHANGELOG.md` has no entries for the version, then archives, signs, notarizes and
staples, and writes:

- `build/release/Lirnyk-0.3.0.dmg` — the file to publish
- `build/release/notes-0.3.0.md` — the release notes: the changelog section, install steps and the DMG's SHA-256

After fixing the changelog, `make notes` regenerates the notes without rebuilding. Check the DMG once by
opening it and launching the app from it.

## 4. Push and tag

```
git push origin main
git tag v0.3.0
git push origin v0.3.0
```

The tag is `v` + `MARKETING_VERSION`. Pushing it does not publish anything by itself.

## 5. Publish the GitHub release

On https://github.com/cheyako/lirnyk-app/releases/new:

- **Tag:** `v0.3.0`
- **Title:** `Lirnyk 0.3.0`
- **Description:** the contents of `build/release/notes-0.3.0.md`
- **Attach:** `build/release/Lirnyk-0.3.0.dmg`
- Leave **Set as a pre-release** unchecked (pre-releases are invisible to _Check for Updates_) and keep
  **Set as the latest release** checked.

Or with the GitHub CLI, logged in as an account that can publish to `cheyako/lirnyk-app`:

```
gh release create v0.3.0 build/release/Lirnyk-0.3.0.dmg --repo cheyako/lirnyk-app \
  --title "Lirnyk 0.3.0" --notes-file build/release/notes-0.3.0.md
```

Then, in an installed older version, _Settings → About → Check for Updates_ should offer the new release.
