#!/usr/bin/env bash
# Writes the Homebrew cask for a released version into the tap (cheyako/homebrew-tap).
# Usage: scripts/cask.sh [version]   (default: MARKETING_VERSION from project.yml)
# Reads the SHA-256 from build/release/Lirnyk.dmg, the file attached to the release.
# The tap checkout defaults to ../homebrew-tap; override with TAP_DIR.
set -euo pipefail

# Prints the cask for a version and the SHA-256 of its Lirnyk.dmg.
cask_file() { # version, sha256
  cat <<CASK
cask "lirnyk" do
  version "$1"
  sha256 "$2"

  url "https://github.com/cheyako/lirnyk-app/releases/download/v#{version}/Lirnyk.dmg",
      verified: "github.com/cheyako/lirnyk-app/"
  name "Lirnyk"
  desc "Rewrite selected text in any app with AI"
  homepage "https://lirnyk.app/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Lirnyk.app"

  uninstall quit: "com.metajourney.lirnyk"

  zap trash: [
    "~/Library/Application Support/Lirnyk",
    "~/Library/Preferences/com.metajourney.lirnyk.plist",
  ]
end
CASK
}

main() {
  cd "$(dirname "$0")/.."
  local version=${1:-$(sed -nE 's/^ *MARKETING_VERSION: "(.*)"/\1/p' project.yml)}
  local dmg=build/release/Lirnyk.dmg tap=${TAP_DIR:-../homebrew-tap}
  [[ -f $dmg ]] || { echo "error: $dmg not found; run 'make release' first" >&2; return 1; }
  [[ -d $tap/.git ]] || { echo "error: no tap checkout at $tap (set TAP_DIR)" >&2; return 1; }
  mkdir -p "$tap/Casks"
  cask_file "$version" "$(shasum -a 256 "$dmg" | awk '{print $1}')" > "$tap/Casks/lirnyk.rb"
  echo "==> Wrote $tap/Casks/lirnyk.rb for $version; commit and push the tap to publish it"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
