#!/usr/bin/env bash
# Tests for release.sh helpers, using fake `security` / `xcrun` on PATH.
set -uo pipefail
cd "$(dirname "$0")/.."

FAKES=$(mktemp -d)
trap 'rm -rf "$FAKES"' EXIT
export PATH="$FAKES:$PATH"
# shellcheck source=release.sh
source scripts/release.sh
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

echo "$failures failure(s)"
exit $(( failures > 0 ))
