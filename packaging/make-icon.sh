#!/usr/bin/env bash
# Produce mc-gui.icns from the committed 1024px source PNG via sips + iconutil.
# No Python/PIL dependency (usable in CI).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${1:-$SCRIPT_DIR/../artifacts/build}"
SRC_PNG="$SCRIPT_DIR/icon-asset/mc-gui-icon-1024.png"
ICONSET_DIR="$OUT_DIR/mc-gui.iconset"
ICNS="$OUT_DIR/mc-gui.icns"

command -v sips >/dev/null 2>&1 || { echo "ERROR: sips required (Xcode command line tools)." >&2; exit 1; }
command -v iconutil >/dev/null 2>&1 || { echo "ERROR: iconutil required (Xcode command line tools)." >&2; exit 1; }

test -s "$SRC_PNG" || { echo "ERROR: source icon missing: $SRC_PNG" >&2; exit 1; }
mkdir -p "$OUT_DIR"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
for spec in \
    "icon_16x16.png 16" \
    "icon_16x16@2x.png 32" \
    "icon_32x32.png 32" \
    "icon_32x32@2x.png 64" \
    "icon_128x128.png 128" \
    "icon_128x128@2x.png 256" \
    "icon_256x256.png 256" \
    "icon_256x256@2x.png 512" \
    "icon_512x512.png 512" \
    "icon_512x512@2x.png 1024"
do
    set -- $spec
    sips -z "$2" "$2" "$SRC_PNG" --out "$ICONSET_DIR/$1" >/dev/null
done

rm -f "$ICNS"
iconutil -c icns "$ICONSET_DIR" -o "$ICNS"
test -s "$ICNS" || { echo "ERROR: icns generation failed." >&2; exit 1; }
echo "Generated $ICNS"
