#!/usr/bin/env bash
# Writes GitHub release notes for a version: its CHANGELOG.md section, install steps and the DMG's SHA-256.
# Usage: scripts/notes.sh [version]   (default: MARKETING_VERSION from project.yml)
# Output: build/release/notes-<version>.md (also printed).
set -euo pipefail

# Prints the body of the "## <version> …" section of a changelog, without blank lines at either end.
# Fails when the section is missing or empty.
changelog_section() { # version, changelog file
  local body
  body=$(awk -v version="$1" '
    /^## / { if (found) exit; found = ($2 == version); next }
    found { lines[++n] = $0; if ($0 ~ /[^[:space:]]/) { if (!first) first = n; last = n } }
    END { for (i = first; i && i <= last; i++) print lines[i] }
  ' "$2")
  if [[ -z $body ]]; then
    echo "error: $2 has no entries under '## $1'" >&2
    return 1
  fi
  echo "$body"
}

# Prints the full release notes; the SHA-256 is a placeholder until the DMG exists.
release_notes() { # version, changelog file, dmg path
  local section sha
  section=$(changelog_section "$1" "$2") || return 1
  if [[ -f $3 ]]; then
    sha=$(shasum -a 256 "$3" | awk '{print $1}')
  else
    echo "warning: $3 not found; run 'make release' to fill in the SHA-256" >&2
    sha="<run make release first>"
  fi
  cat <<NOTES
$section

### Install

This build is signed with a Developer ID and **notarized by Apple**.

1. Open the DMG and drag **Lirnyk** into **Applications** (replace the old copy when updating).
2. Open Lirnyk. On first install, grant **Accessibility** access, then pick an AI provider and add its API key in Settings.

Requires macOS 14 or later.

**SHA-256:** \`$sha\`
NOTES
}

main() {
  cd "$(dirname "$0")/.."
  local version=${1:-$(sed -nE 's/^ *MARKETING_VERSION: "(.*)"/\1/p' project.yml)}
  local out=build/release/notes-$version.md
  mkdir -p build/release
  release_notes "$version" CHANGELOG.md "build/release/Lirnyk-$version.dmg" > "$out"
  cat "$out"
  echo "==> Wrote $out" >&2
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
