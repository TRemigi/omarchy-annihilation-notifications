#!/bin/bash
# Renders test/motion-scene.qml offscreen and assembles a contact sheet (needs ImageMagick).
#   bash test/motion-filmstrip.sh [outdir]     -> outdir/sheet.png
set -eu
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
OUT=${1:-$(mktemp -d)}; mkdir -p "$OUT"
env -u DISPLAY -u WAYLAND_DISPLAY QT_QPA_PLATFORMTHEME= QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  timeout 30 "${QML:-/usr/lib/qt6/bin/qml}" "$HERE/motion-scene.qml" -- "$OUT" >/dev/null 2>&1 || true
ls "$OUT"/*.png >/dev/null 2>&1 || { echo "no frames were written" >&2; exit 1; }
row() { magick "$@" +append; }
magick \( $(for f in a0_before b0_arrive b1 b2 b3 b4 b5_settled; do echo "$OUT/$f.png"; done) +append \) \
       \( $(for f in c0_leave c1 c2 c3 c4_closed; do echo "$OUT/$f.png"; done) +append \) -background '#1c1a12' -append "$OUT/sheet.png"
echo "$OUT/sheet.png"
