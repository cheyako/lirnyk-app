#!/usr/bin/env bash
# Builds a Developer ID signed, notarized and stapled Lirnyk DMG.
# Prerequisites (once):
#   1. "Developer ID Application" certificate for team 2S5U65Y5CZ in the login keychain.
#   2. xcrun notarytool store-credentials lirnyk-notary --apple-id <id> --team-id 2S5U65Y5CZ
# Override the certificate with SIGN_IDENTITY=<SHA-1> when several match.
set -euo pipefail

TEAM_ID=2S5U65Y5CZ
NOTARY_PROFILE="${NOTARY_PROFILE:-lirnyk-notary}"
OUT=build/release

# Prints the SHA-1 of the single valid "Developer ID Application" certificate for TEAM_ID.
resolve_signing_identity() {
  if [[ -n "${SIGN_IDENTITY:-}" ]]; then echo "$SIGN_IDENTITY"; return 0; fi
  local matches count
  matches=$(security find-identity -v -p codesigning |
    grep "\"Developer ID Application: .*($TEAM_ID)\"" |
    awk '{print $2}' || true)
  count=$(grep -c . <<<"$matches" || true)
  if [[ $count -eq 0 ]]; then
    echo "error: no valid 'Developer ID Application' certificate for team $TEAM_ID in keychain" >&2
    return 1
  fi
  if [[ $count -gt 1 ]]; then
    echo "error: several Developer ID certificates for team $TEAM_ID; set SIGN_IDENTITY to one of:" >&2
    echo "$matches" >&2
    return 1
  fi
  echo "$matches"
}

# Submits a file for notarization; fails with the notary log unless Apple accepts it.
notarize() {
  local file=$1 result id status
  result=$(xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)
  id=$(plutil -extract id raw -o - - <<<"$result")
  status=$(plutil -extract status raw -o - - <<<"$result")
  echo "    notarization $id: $status"
  if [[ "$status" != "Accepted" ]]; then
    xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    return 1
  fi
}

main() {
  cd "$(dirname "$0")/.."
  local identity version app stage dmg
  identity=$(resolve_signing_identity)
  version=$(sed -nE 's/^ *MARKETING_VERSION: "(.*)"/\1/p' project.yml)

  rm -rf "$OUT"
  mkdir -p "$OUT"
  xcodegen generate --quiet

  # Archive with the project's normal signing; the developer-id export re-signs every
  # nested bundle (including SwiftPM resource bundles) with the Developer ID identity.
  echo "==> Archiving $version"
  xcodebuild -project Lirnyk.xcodeproj -scheme Lirnyk -configuration Release \
    -archivePath "$OUT/Lirnyk.xcarchive" archive -quiet

  echo "==> Exporting with $identity"
  plutil -replace signingCertificate -string "$identity" -o "$OUT/ExportOptions.plist" scripts/ExportOptions.plist
  xcodebuild -exportArchive -archivePath "$OUT/Lirnyk.xcarchive" \
    -exportPath "$OUT/export" -exportOptionsPlist "$OUT/ExportOptions.plist" -quiet
  app="$OUT/export/Lirnyk.app"
  codesign --verify --deep --strict --verbose=2 "$app"
  local signature
  signature=$(codesign -dv --verbose=2 "$app" 2>&1)
  [[ $signature == *"Authority=Developer ID Application: "*"($TEAM_ID)"* ]] ||
    { echo "error: exported app is not signed with Developer ID" >&2; return 1; }

  echo "==> Notarizing app"
  ditto -c -k --keepParent "$app" "$OUT/Lirnyk.zip"
  notarize "$OUT/Lirnyk.zip"
  xcrun stapler staple "$app"

  echo "==> Building DMG"
  stage="$OUT/dmg"
  mkdir -p "$stage"
  ditto "$app" "$stage/Lirnyk.app"
  ln -s /Applications "$stage/Applications"
  dmg="$OUT/Lirnyk-$version.dmg"
  hdiutil create -volname Lirnyk -srcfolder "$stage" -ov -format UDZO "$dmg"
  codesign --sign "$identity" --timestamp "$dmg"

  echo "==> Notarizing DMG"
  notarize "$dmg"
  xcrun stapler staple "$dmg"
  spctl --assess --type open --context context:primary-signature --verbose "$dmg"

  echo "Done: $dmg"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
