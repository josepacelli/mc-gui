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
VERSION="0.1.0"
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

echo "==> Create DMG"
VOLNAME="Midnight Commander GUI"
RW_DMG="$ARTIFACTS/mc-gui-rw.dmg"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/.background"
cp -R "$APP_DIR" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"
cp "$SCRIPT_DIR/dmg-assets/background.png" "$STAGE_DIR/.background/background.png"
chflags hidden "$STAGE_DIR/.background"

rm -f "$RW_DMG" "$DMG_PATH"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE_DIR" -ov -format UDRW -fs HFS+ "$RW_DMG" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach "$RW_DMG" -readwrite)"
MOUNT_DIR="$(echo "$ATTACH_OUTPUT" | grep -E '^/dev/' | awk -F'\t' '{print $NF}' | tail -1 | sed 's/^[[:space:]]*//')"

[ -d "$MOUNT_DIR/.fseventsd" ] && chflags hidden "$MOUNT_DIR/.fseventsd"

echo "==> Style DMG window (Finder)"
osascript <<OSA
tell application "Finder"
    tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 700, 770}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "$APP_BUNDLE_NAME" of container window to {250, 150}
        set position of item "Applications" of container window to {250, 500}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
OSA

[ -d "$MOUNT_DIR/.fseventsd" ] && chflags hidden "$MOUNT_DIR/.fseventsd"

sync
DETACHED=0
for attempt in 1 2 3 4 5; do
    if hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null; then
        DETACHED=1
        break
    fi
    sleep 2
done
[ "$DETACHED" -eq 1 ] || hdiutil detach "$MOUNT_DIR" -force -quiet

hdiutil convert "$RW_DMG" -format UDZO -ov -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG"

echo "Done: $DMG_PATH"

if [ "$OPEN_AFTER_BUILD" -eq 1 ]; then
    open "$DMG_PATH"
fi
