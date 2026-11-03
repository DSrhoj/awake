#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Awake"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Awake/Info.plist 2>/dev/null || echo "1.0.0")"
DIST="$ROOT/dist"
DERIVED="$ROOT/build/package"
APP_SRC="$DERIVED/Build/Products/Release/${APP_NAME}.app"
STAGE="$DIST/stage"
DMG="$DIST/${APP_NAME}-${VERSION}.dmg"
ZIP="$DIST/${APP_NAME}-${VERSION}.zip"

echo "→ Building Release…"
rm -rf "$DERIVED" "$DIST"
mkdir -p "$DIST" "$STAGE"

xcodebuild \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  ENABLE_DEBUG_DYLIB=NO \
  build

if [[ ! -d "$APP_SRC" ]]; then
  echo "Build failed: missing $APP_SRC" >&2
  exit 1
fi

echo "→ Staging app…"
cp -R "$APP_SRC" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "→ Creating ZIP…"
ditto -c -k --sequesterRsrc --keepParent "$STAGE/${APP_NAME}.app" "$ZIP"

echo "→ Creating DMG…"
if hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"
then
  DMG_OK=1
else
  echo "  (DMG skipped — hdiutil unavailable in this environment. ZIP is enough.)"
  DMG_OK=0
fi

rm -rf "$STAGE"

echo
echo "Done."
echo "  ZIP: $ZIP"
if [[ "$DMG_OK" -eq 1 ]]; then
  echo "  DMG: $DMG"
fi
echo
echo "Install: unzip, then drag ${APP_NAME}.app into Applications."
echo "First launch: right-click → Open (ad-hoc signed / personal build)."
