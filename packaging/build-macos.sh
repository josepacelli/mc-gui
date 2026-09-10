#!/usr/bin/env bash
# Build mc-gui (MCGuiApp, Swift/SwiftUI) for macOS (arm64): swift build -c
# release, assemble the .app bundle, and create a drag-to-Applications DMG.
# Unsigned (development build).
#
# Usage: ./packaging/build-macos.sh [VERSION]
#   VERSION defaults to 0.1.0; used for CFBundle* and the DMG filename.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
VERSION="${1:-0.1.0}"

ARTIFACTS="$REPO_ROOT/artifacts"
APP_BUNDLE_NAME="Midnight Commander GUI.app"
APP_EXECUTABLE_NAME="mc-gui"
SPM_PRODUCT_NAME="MCGuiApp"
APP_DIR="$ARTIFACTS/$APP_BUNDLE_NAME"
STAGE_DIR="$ARTIFACTS/dmg-stage"
ICON_SOURCE_DIR="$ARTIFACTS/build"
DMG_PATH="$ARTIFACTS/mc-gui-$VERSION-arm64.dmg"

for tool in swift hdiutil plutil file; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: $tool required." >&2; exit 1; }
done

echo "==> Clean artifacts"
rm -rf "$ARTIFACTS"
mkdir -p "$ARTIFACTS"

echo "==> Generate icon"
"$SCRIPT_DIR/make-icon.sh" "$ICON_SOURCE_DIR"

echo "==> Build ($VERSION, release, arm64)"
swift build --package-path "$REPO_ROOT" -c release --arch arm64
BIN_PATH="$(swift build --package-path "$REPO_ROOT" -c release --arch arm64 --show-bin-path)"

echo "==> Assemble $APP_BUNDLE_NAME"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH/$SPM_PRODUCT_NAME" "$APP_DIR/Contents/MacOS/$APP_EXECUTABLE_NAME"

cp "$ICON_SOURCE_DIR/mc-gui.icns" "$APP_DIR/Contents/Resources/mc-gui.icns"

sed "s/__VERSION__/$VERSION/g" "$SCRIPT_DIR/Info.plist" > "$APP_DIR/Contents/Info.plist"

echo "==> Verify bundle"
plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null
test -s "$APP_DIR/Contents/Resources/mc-gui.icns" || { echo "ERROR: icns missing." >&2; exit 1; }
BIN_FILE="$(file "$APP_DIR/Contents/MacOS/$APP_EXECUTABLE_NAME")"
echo "$BIN_FILE"
case "$BIN_FILE" in
    *arm64*executable*) ;;
    *executable*arm64*) ;;
    *) echo "ERROR: executable is not a Mach-O arm64 executable." >&2; exit 1 ;;
esac

echo "==> Create DMG"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$APP_DIR" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "$APP_EXECUTABLE_NAME" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "Done: $DMG_PATH"

open $DMG_PATH
