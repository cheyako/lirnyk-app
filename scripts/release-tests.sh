#!/usr/bin/env bash
# Tests for release.sh helpers, using fake `security` / `xcrun` on PATH.
set -uo pipefail
cd "$(dirname "$0")/.."

FAKES=$(mktemp -d)
trap 'rm -rf "$FAKES"' EXIT
export PATH="$FAKES:$PATH"
# shellcheck source=release.sh
source scripts/release.sh
# shellcheck source=cask.sh
source scripts/cask.sh
set +e # release.sh enables errexit; checks below expect failing commands
failures=0

check() { # name, expected exit, command...
  local name=$1 expected=$2; shift 2
  local output status
  output=$("$@" 2>&1); status=$?
  if [[ $status -eq $expected ]]; then echo "✔ $name"; else echo "✘ $name (exit $status, want $expected): $output"; failures=$((failures + 1)); fi
  LAST_OUTPUT=$output
}

fake_security() { # lines printed by `security find-identity`
  printf '#!/usr/bin/env bash\ncat <<"OUT"\n%s\nOUT\n' "$1" > "$FAKES/security"
  chmod +x "$FAKES/security"
}

fake_xcrun() { # JSON printed by `notarytool submit`; `notarytool log` prints LOG-CALLED
  cat > "$FAKES/xcrun" <<SH
#!/usr/bin/env bash
if [[ "\$2" == "log" ]]; then echo LOG-CALLED; exit 0; fi
echo '$1'
SH
  chmod +x "$FAKES/xcrun"
}

OURS='  1) AAAA1111AAAA1111AAAA1111AAAA1111AAAA1111 "Developer ID Application: Yakov Korotenko (2S5U65Y5CZ)"'
OTHER_TEAM='  2) BBBB2222BBBB2222BBBB2222BBBB2222BBBB2222 "Developer ID Application: Someone Else (ZZZZZZZZZZ)"'
DEV='  3) CCCC3333CCCC3333CCCC3333CCCC3333CCCC3333 "Apple Development: korotenko.yakov@gmail.com (C83328R93D)"'

fake_security "$OURS"$'\n'"$OTHER_TEAM"$'\n'"$DEV"
check "resolves the team's Developer ID by SHA-1" 0 resolve_signing_identity
[[ $LAST_OUTPUT == "AAAA1111AAAA1111AAAA1111AAAA1111AAAA1111" ]] || { echo "✘ wrong identity: $LAST_OUTPUT"; failures=$((failures + 1)); }

fake_security "$OTHER_TEAM"$'\n'"$DEV"
check "fails without a Developer ID for our team" 1 resolve_signing_identity

fake_security "$OURS"$'\n''  4) DDDD4444DDDD4444DDDD4444DDDD4444DDDD4444 "Developer ID Application: Yakov Korotenko (2S5U65Y5CZ)"'
check "fails when several Developer IDs match" 1 resolve_signing_identity

fake_xcrun '{"id":"abc-123","status":"Accepted","message":"Processing complete"}'
check "notarize accepts an Accepted submission" 0 notarize dummy.zip

fake_xcrun '{"id":"abc-456","status":"Invalid","message":"Processing complete"}'
check "notarize fails on Invalid" 1 notarize dummy.zip
[[ $LAST_OUTPUT == *LOG-CALLED* ]] && echo "✔ notarize prints the notary log on failure" || { echo "✘ notary log not printed: $LAST_OUTPUT"; failures=$((failures + 1)); }

CHANGELOG=$FAKES/CHANGELOG.md
cat > "$CHANGELOG" <<'MD'
# Changelog

## Unreleased

## 0.3.0 — 2026-11-01

Third.

### New
- Thing

## 0.2.0 — 2026-10-27
Second.

## 0.1.0 — 2026-10-07
First.
MD
check "changelog_section extracts a middle version" 0 changelog_section 0.3.0 "$CHANGELOG"
[[ $LAST_OUTPUT == $'Third.\n\n### New\n- Thing' ]] && echo "✔ section is trimmed and stops at the next version" || { echo "✘ wrong section: $LAST_OUTPUT"; failures=$((failures + 1)); }
check "changelog_section extracts the last version" 0 changelog_section 0.1.0 "$CHANGELOG"
[[ $LAST_OUTPUT == "First." ]] || { echo "✘ wrong last section: $LAST_OUTPUT"; failures=$((failures + 1)); }
check "changelog_section fails for a missing version" 1 changelog_section 9.9.9 "$CHANGELOG"
check "changelog_section fails for an empty section" 1 changelog_section Unreleased "$CHANGELOG"
check "changelog_section does not match a version prefix" 1 changelog_section 0.3 "$CHANGELOG"

printf 'dmg' > "$FAKES/Lirnyk.dmg"
check "release_notes includes the DMG's SHA-256" 0 release_notes 0.2.0 "$CHANGELOG" "$FAKES/Lirnyk.dmg"
[[ $LAST_OUTPUT == Second.* && $LAST_OUTPUT == *"\`$(shasum -a 256 "$FAKES/Lirnyk.dmg" | awk '{print $1}')\`"* ]] \
  && echo "✔ notes start with the section and end with the checksum" || { echo "✘ wrong notes: $LAST_OUTPUT"; failures=$((failures + 1)); }
check "release_notes works before the DMG exists" 0 release_notes 0.2.0 "$CHANGELOG" "$FAKES/missing.dmg"
[[ $LAST_OUTPUT == *"run make release first"* ]] || { echo "✘ no placeholder: $LAST_OUTPUT"; failures=$((failures + 1)); }
check "release_notes fails without a changelog section" 1 release_notes 9.9.9 "$CHANGELOG" "$FAKES/Lirnyk.dmg"

check "cask_file writes the version and checksum" 0 cask_file 1.2.3 abc123
[[ $LAST_OUTPUT == *'version "1.2.3"'* && $LAST_OUTPUT == *'sha256 "abc123"'* \
  && $LAST_OUTPUT == *'releases/download/v#{version}/Lirnyk.dmg'* ]] \
  && echo "✔ cask points at the version's Lirnyk.dmg" || { echo "✘ wrong cask: $LAST_OUTPUT"; failures=$((failures + 1)); }

echo "$failures failure(s)"
exit $(( failures > 0 ))
