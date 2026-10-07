#!/usr/bin/env bash
# Builds a Developer ID signed Lirnyk DMG WITHOUT Apple notarization (fast, local/testing use).
# Recipients see a Gatekeeper warning on first launch; use scripts/release.sh for public builds.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=release.sh
source scripts/release.sh   # for TEAM_ID and resolve_signing_identity

OUT=build/dmg
identity=$(resolve_signing_identity)
version=$(sed -nE 's/^ *MARKETING_VERSION: "(.*)"/\1/p' project.yml)

rm -rf "$OUT"
mkdir -p "$OUT"
xcodegen generate --quiet

echo "==> Archiving $version"
xcodebuild -project Lirnyk.xcodeproj -scheme Lirnyk -configuration Release \
  -archivePath "$OUT/Lirnyk.xcarchive" archive -quiet

echo "==> Exporting with $identity"
plutil -replace signingCertificate -string "$identity" -o "$OUT/ExportOptions.plist" scripts/ExportOptions.plist
xcodebuild -exportArchive -archivePath "$OUT/Lirnyk.xcarchive" \
  -exportPath "$OUT/export" -exportOptionsPlist "$OUT/ExportOptions.plist" -quiet
app="$OUT/export/Lirnyk.app"
codesign --verify --deep --strict "$app"

echo "==> Building DMG"
stage="$OUT/stage"
mkdir -p "$stage"
ditto "$app" "$stage/Lirnyk.app"
ln -s /Applications "$stage/Applications"
dmg="$OUT/Lirnyk-$version-unnotarized.dmg"
hdiutil create -volname Lirnyk -srcfolder "$stage" -ov -format UDZO "$dmg" >/dev/null
codesign --sign "$identity" --timestamp "$dmg"

echo "Done: $dmg (not notarized)"
