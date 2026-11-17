#!/usr/bin/env bash
# Build mc-gui (MCGuiApp, Swift/SwiftUI) for macOS (arm64): swift build -c
# release, assemble the .app bundle, and create a macOS .pkg installer.
# Unsigned (development build).
#
# Usage: ./packaging/build-macos.sh [VERSION] [--open]
#   VERSION defaults to 1.0.1; used for CFBundle*, pkg version, and the PKG filename.
#   --open reveals the built PKG in Finder once done (optional).
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
PKG_IDENTIFIER="mcgui.jpmo.dev.br.pkg"
APP_DIR="$ARTIFACTS/$APP_BUNDLE_NAME"
ICON_SOURCE_DIR="$ARTIFACTS/build"
PKG_STAGE_DIR="$ARTIFACTS/pkg-stage"
PKG_ROOT="$PKG_STAGE_DIR/root"
PKG_RESOURCES="$PKG_STAGE_DIR/resources"
COMPONENT_PLIST="$PKG_STAGE_DIR/component.plist"
COMPONENT_PKG_NAME="mc-gui-component.pkg"
COMPONENT_PKG="$PKG_STAGE_DIR/$COMPONENT_PKG_NAME"
DIST_XML="$PKG_STAGE_DIR/distribution.xml"
PKG_PATH="$ARTIFACTS/mc-gui-$VERSION-arm64.pkg"

for tool in swift plutil file codesign pkgbuild productbuild pkgutil installer; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: $tool required." >&2; exit 1; }
done
test -x /usr/libexec/PlistBuddy || { echo "ERROR: /usr/libexec/PlistBuddy required." >&2; exit 1; }

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

echo "==> Sign app bundle ($SIGN_IDENTITY)"
# swift build only ad-hoc-signs the raw binary; re-signing the whole assembled
# bundle here seals Info.plist + Resources too. Without this, Gatekeeper sees a
# signed binary inside an unsealed bundle and reports the app as "damaged"
# instead of showing the normal (bypassable) unidentified-developer prompt.
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "==> Stage PKG payload"
rm -rf "$PKG_STAGE_DIR"
mkdir -p "$PKG_ROOT/Applications" "$PKG_RESOURCES"
ditto "$APP_DIR" "$PKG_ROOT/Applications/$APP_BUNDLE_NAME"
cp "$SCRIPT_DIR/pkg-resources/"* "$PKG_RESOURCES/"
cp "$REPO_ROOT/LICENSE" "$PKG_RESOURCES/LICENSE"

pkgbuild --analyze --root "$PKG_ROOT" "$COMPONENT_PLIST" >/dev/null
idx=0
while /usr/libexec/PlistBuddy -c "Set :${idx}:BundleIsRelocatable false" "$COMPONENT_PLIST" 2>/dev/null; do
    idx=$((idx + 1))
done
[ "$idx" -gt 0 ] || { echo "ERROR: no bundles found in $COMPONENT_PLIST." >&2; exit 1; }

echo "==> Build component package"
pkgbuild \
    --root "$PKG_ROOT" \
    --component-plist "$COMPONENT_PLIST" \
    --identifier "$PKG_IDENTIFIER" \
    --version "$VERSION" \
    --install-location "/" \
    "$COMPONENT_PKG"

echo "==> Build distribution PKG"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__COMPONENT_PKG__/$COMPONENT_PKG_NAME/g" \
    "$SCRIPT_DIR/pkg/distribution.xml" > "$DIST_XML"

rm -f "$PKG_PATH"
productbuild \
    --distribution "$DIST_XML" \
    --package-path "$PKG_STAGE_DIR" \
    --resources "$PKG_RESOURCES" \
    "$PKG_PATH"

echo "==> Verify PKG"
test -s "$PKG_PATH" || { echo "ERROR: PKG missing or empty." >&2; exit 1; }
installer -pkginfo -pkg "$PKG_PATH"
pkgutil --payload-files "$COMPONENT_PKG" | grep -q "Applications/$APP_BUNDLE_NAME/Contents/MacOS/$APP_EXECUTABLE_NAME" || {
    echo "ERROR: app executable missing from PKG payload." >&2
    exit 1
}

rm -rf "$PKG_STAGE_DIR"

if [ "$OPEN_AFTER_BUILD" -eq 1 ]; then
    open -R "$PKG_PATH"
fi

echo "Done: $PKG_PATH"
