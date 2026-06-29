#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.1.1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/.build/arm64-apple-macosx/release"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/TokenGlance.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ZIP_NAME="TokenGlance-${VERSION}-arm64.zip"
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-"-"}"
NOTARIZE_APP="${NOTARIZE_APP:-auto}"

rm -rf "$DIST_DIR"
mkdir -p "$MACOS" "$RESOURCES"

swift test
swift build -c release --arch arm64

cp "$BUILD_DIR/TokenGlance" "$MACOS/TokenGlance"
cp -R "$ROOT/Sources/TokenGlance/Resources/." "$RESOURCES/"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>TokenGlance</string>
  <key>CFBundleIdentifier</key>
  <string>dev.marcelbreuer.tokenglance</string>
  <key>CFBundleIconFile</key>
  <string>TokenGlance</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>TokenGlance</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Marcel Breuer. MIT License.</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

if [[ "$SIGN_IDENTITY" == "-" || -z "$SIGN_IDENTITY" ]]; then
  codesign --force --deep --sign - "$APP_DIR"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

codesign --verify --deep --strict "$APP_DIR"
file "$MACOS/TokenGlance" | grep -q "arm64"

create_zip() {
  rm -f "$DIST_DIR/$ZIP_NAME" "$DIST_DIR/$ZIP_NAME.sha256"
  cd "$DIST_DIR"
  /usr/bin/ditto -c -k --norsrc --keepParent "TokenGlance.app" "$ZIP_NAME"
  shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256"
}

create_zip

should_notarize=false
if [[ "$SIGN_IDENTITY" != "-" && -n "$SIGN_IDENTITY" ]]; then
  if [[ "$NOTARIZE_APP" == "1" || "$NOTARIZE_APP" == "true" ]]; then
    should_notarize=true
  elif [[ "$NOTARIZE_APP" == "auto" ]]; then
    if [[ -n "${NOTARYTOOL_KEYCHAIN_PROFILE:-}" ]] \
      || { [[ -n "${APPLE_ID:-}" ]] && [[ -n "${APPLE_TEAM_ID:-}" ]] \
        && [[ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; }; then
      should_notarize=true
    fi
  fi
fi

if [[ "$should_notarize" == "true" ]]; then
  if [[ -n "${NOTARYTOOL_KEYCHAIN_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DIST_DIR/$ZIP_NAME" \
      --keychain-profile "$NOTARYTOOL_KEYCHAIN_PROFILE" \
      --wait
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" \
    && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$DIST_DIR/$ZIP_NAME" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait
  else
    echo "Notarization requested but no notarytool credentials were provided." >&2
    exit 1
  fi

  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"
  spctl -a -vv "$APP_DIR"
  create_zip
elif [[ "$NOTARIZE_APP" == "1" || "$NOTARIZE_APP" == "true" ]]; then
  echo "Notarization requested but Developer ID signing is not configured." >&2
  exit 1
fi

echo "$DIST_DIR/$ZIP_NAME"
echo "$DIST_DIR/$ZIP_NAME.sha256"
