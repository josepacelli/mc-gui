#!/usr/bin/env bash
# Build mc-gui (MCGuiApp, Swift/SwiftUI) for macOS (arm64): swift build -c
# release, assemble the .app bundle, and create a drag-to-Applications DMG.
# Unsigned (development build).
#
# Usage: ./packaging/build-macos.sh [VERSION] [--open]
#   VERSION defaults to 0.1.0; used for CFBundle* and the DMG filename.
#   --open reveals the built DMG in Finder once done (optional).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
VERSION="1.0.1"
OPEN_AFTER_BUILD=0
for arg in "$@"; do
    case "$arg" in
        --open) OPEN_AFTER_BUILD=1 ;;
        *) VERSION="$arg" ;;
    esac
done

ARTIFACTS="$REPO_ROOT/artifacts"
APP_BUNDLE_NAME="Midnight Commander GUI.app"
APP_EXECUTABLE_NAME="mc-gui"
SPM_PRODUCT_NAME="MCGuiApp"
APP_DIR="$ARTIFACTS/$APP_BUNDLE_NAME"
STAGE_DIR="$ARTIFACTS/dmg-stage"
ICON_SOURCE_DIR="$ARTIFACTS/build"
DMG_PATH="$ARTIFACTS/mc-gui-$VERSION-arm64.dmg"

for tool in swift hdiutil plutil file create-dmg; do
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

echo "==> Copy localized resource bundles"
shopt -s nullglob
RESOURCE_BUNDLES=("$BIN_PATH"/MCGui_*.bundle)
shopt -u nullglob
[ ${#RESOURCE_BUNDLES[@]} -gt 0 ] || { echo "ERROR: no MCGui_*.bundle found in $BIN_PATH." >&2; exit 1; }
for bundle in "${RESOURCE_BUNDLES[@]}"; do
    cp -R "$bundle" "$APP_DIR/Contents/Resources/"
done

sed "s/__VERSION__/$VERSION/g" "$SCRIPT_DIR/Info.plist" > "$APP_DIR/Contents/Info.plist"

echo "==> Verify bundle"
plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null
test -s "$APP_DIR/Contents/Resources/mc-gui.icns" || { echo "ERROR: icns missing." >&2; exit 1; }
for bundle in "${RESOURCE_BUNDLES[@]}"; do
    test -d "$APP_DIR/Contents/Resources/$(basename "$bundle")" || { echo "ERROR: $(basename "$bundle") missing from app bundle." >&2; exit 1; }
done
BIN_FILE="$(file "$APP_DIR/Contents/MacOS/$APP_EXECUTABLE_NAME")"
echo "$BIN_FILE"
case "$BIN_FILE" in
    *arm64*executable*) ;;
    *executable*arm64*) ;;
    *) echo "ERROR: executable is not a Mach-O arm64 executable." >&2; exit 1 ;;
esac

SIGN_IDENTITY="-"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "mc-gui Local Developer"; then
    SIGN_IDENTITY="mc-gui Local Developer"
fi

echo "==> Sign app bundle ($SIGN_IDENTITY)"
# swift build only ad-hoc-signs the raw binary; re-signing the whole assembled
# bundle here seals Info.plist + Resources too. Without this, Gatekeeper sees a
# signed binary inside an unsealed bundle and reports the app as "damaged"
# instead of showing the normal (bypassable) unidentified-developer prompt.
# Prefers the local self-signed "mc-gui Local Developer" identity when present
# (stable identity across rebuilds - avoids the keychain/TCC permission resets
# ad-hoc signing causes) and falls back to ad-hoc ("-") on any other machine.
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "==> Create DMG"
VOLNAME="Midnight Commander"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$APP_DIR" "$STAGE_DIR/"

rm -f "$DMG_PATH"
create-dmg \
    --volname "$VOLNAME" \
    --background "$SCRIPT_DIR/dmg-assets/background.png" \
    --window-pos 200 120 \
    --window-size 500 650 \
    --icon-size 128 \
    --icon "$APP_BUNDLE_NAME" 250 150 \
    --app-drop-link 250 500 \
    --hdiutil-quiet \
    "$DMG_PATH" \
    "$STAGE_DIR"

echo "Done: $DMG_PATH"
