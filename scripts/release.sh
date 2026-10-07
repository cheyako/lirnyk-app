#!/usr/bin/env bash
# Builds a Developer ID signed, notarized and stapled Lirnyk DMG.
# Prerequisites (once):
#   1. "Developer ID Application" certificate for team 2S5U65Y5CZ in the login keychain.
#   2. xcrun notarytool store-credentials lirnyk-notary --apple-id <id> --team-id 2S5U65Y5CZ
set -euo pipefail
cd "$(dirname "$0")/.."

NOTARY_PROFILE="${NOTARY_PROFILE:-lirnyk-notary}"
OUT=build/release
VERSION=$(sed -nE 's/^ *MARKETING_VERSION: "(.*)"/\1/p' project.yml)

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "error: no 'Developer ID Application' certificate in keychain" >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
xcodegen generate --quiet

echo "==> Archiving $VERSION"
xcodebuild -project Lirnyk.xcodeproj -scheme Lirnyk -configuration Release \
  -archivePath "$OUT/Lirnyk.xcarchive" archive \
  CODE_SIGN_IDENTITY="Developer ID Application" OTHER_CODE_SIGN_FLAGS="--timestamp" -quiet

echo "==> Exporting"
xcodebuild -exportArchive -archivePath "$OUT/Lirnyk.xcarchive" \
  -exportPath "$OUT/export" -exportOptionsPlist scripts/ExportOptions.plist -quiet
APP="$OUT/export/Lirnyk.app"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Notarizing app"
ditto -c -k --keepParent "$APP" "$OUT/Lirnyk.zip"
xcrun notarytool submit "$OUT/Lirnyk.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"

echo "==> Building DMG"
STAGE="$OUT/dmg"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Lirnyk.app"
ln -s /Applications "$STAGE/Applications"
DMG="$OUT/Lirnyk-$VERSION.dmg"
hdiutil create -volname Lirnyk -srcfolder "$STAGE" -ov -format UDZO "$DMG"
codesign --sign "Developer ID Application" --timestamp "$DMG"

echo "==> Notarizing DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

echo "Done: $DMG"
