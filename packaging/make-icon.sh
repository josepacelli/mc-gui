#!/usr/bin/env bash
# Generate the mc-gui app icon: 1024px source PNG -> .icns via sips + iconutil.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${1:-$SCRIPT_DIR/../artifacts/build}"
SRC_PNG="$OUT_DIR/icon-source.png"
ICONSET_DIR="$OUT_DIR/mc-gui.iconset"
ICNS="$OUT_DIR/mc-gui.icns"

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required to generate the icon." >&2; exit 1; }
command -v sips >/dev/null 2>&1 || { echo "ERROR: sips required (Xcode command line tools)." >&2; exit 1; }
command -v iconutil >/dev/null 2>&1 || { echo "ERROR: iconutil required (Xcode command line tools)." >&2; exit 1; }

mkdir -p "$OUT_DIR"

python3 - "$SRC_PNG" <<'PY'
import sys

from PIL import Image, ImageDraw

out = sys.argv[1]
size = 1024
img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Rounded dark background plate.
margin = 96
d.rounded_rectangle(
    [margin, margin, size - margin, size - margin],
    radius=210,
    fill=(26, 34, 51, 255),
)

# Two side-by-side panels (Midnight Commander layout) with a header row each.
left = (margin + 70, margin + 120)
right = (size - margin - 70, size - margin - 70)
top = margin + 120
bottom = size - margin - 70
gap = 60

panel = (left[0], top, right[0], bottom)
mid_x = (left[0] + right[0]) // 2
inset = 44

# Left panel fill (teal-ish) and header.
d.rounded_rectangle(
    [left[0], top, mid_x - gap // 2, bottom],
    radius=56,
    fill=(40, 120, 140, 255),
)
# Right panel fill (blue).
d.rounded_rectangle(
    [mid_x + gap // 2, top, right[0], bottom],
    radius=56,
    fill=(60, 100, 190, 255),
)
# Header bars (slightly darker) for each panel.
d.rounded_rectangle(
    [left[0] + inset, top + inset, mid_x - gap // 2 - inset, top + inset + 52],
    radius=20,
    fill=(24, 84, 100, 255),
)
d.rounded_rectangle(
    [mid_x + gap // 2 + inset, top + inset, right[0] - inset, top + inset + 52],
    radius=20,
    fill=(38, 66, 132, 255),
)
# Row lines in each panel.
for i in range(5):
    yy = top + inset + 100 + i * 96
    d.rounded_rectangle(
        [left[0] + inset, yy, mid_x - gap // 2 - inset, yy + 40],
        radius=14,
        fill=(150, 210, 220, 255),
    )
    d.rounded_rectangle(
        [mid_x + gap // 2 + inset, yy, right[0] - inset, yy + 40],
        radius=14,
        fill=(150, 175, 225, 255),
    )

img.save(out, "PNG")
PY

# Build the iconset at the standard sizes.
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
