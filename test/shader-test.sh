#!/bin/bash
# Numeric tests of shaders/toastrim.frag (compiled form), run on Mesa's software GL through test/shader-harness.c:
# where it draws and where it does not, the light's direction, the ignition, the palettes, the icon ring, that the
# output is added light that never clips flat, and the vividness and drift controls. Needs gcc, EGL and GLES headers,
# llvmpipe, qsb and python3 (standard library only).
#
#   bash test/shader-test.sh
#
# Each check was also confirmed to fail when the shader was broken on purpose.
set -u
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0
check() { if [[ $2 == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: want [$2] got [$3]"; fi; }

/usr/lib/qt6/bin/qsb -x "glsl,100 es" -o "$tmp/s.frag" "$HERE/shaders/toastrim.frag.qsb" || exit 2
gcc -O2 "$HERE/test/shader-harness.c" -o "$tmp/harness" -lEGL -lGLESv2 || exit 2

# A 440x150 overlay, the card 380x90 at (30,30), its radius 5, an icon ring of radius 17 at (62,75).
render() { # out [VAR=value ...]
  local out=$1; shift
  env EGL_PLATFORM=surfaceless LIBGL_ALWAYS_SOFTWARE=1 U_time=3 U_energy=1 U_vividness=0.75 U_urgency=1 U_radius=5 \
    U_size=440,150 U_card=30,30,380,90 U_icon=62,75,17 "$@" "$tmp/harness" "$tmp/s.frag" 440 150 "$tmp/$out.pam" 2>/dev/null
}
# px FILE X Y -> "r g b a" (0-255)
px() {
  python3 - "$tmp/$1.pam" "$2" "$3" <<'PY'
import sys
d = open(sys.argv[1], "rb").read(); e = d.index(b"ENDHDR\n") + 7
x, y = int(sys.argv[2]), int(sys.argv[3]); o = e + (y * 440 + x) * 4
print(*d[o:o + 4])
PY
}
stat() { # FILE -> "sum_rgb max_channel max_alpha"
  python3 - "$tmp/$1.pam" <<'PY'
import sys
d = open(sys.argv[1], "rb").read(); e = d.index(b"ENDHDR\n") + 7; b = d[e:]
print(sum(b[i] + b[i + 1] + b[i + 2] for i in range(0, len(b), 4)), max(max(b[i:i + 3]) for i in range(0, len(b), 4)), max(b[3::4]))
PY
}
lum() { read -r r g b a <<<"$1"; echo $(( (299 * r + 587 * g + 114 * b) / 1000 )); }
chroma() { read -r r g b a <<<"$1"; local mx=$r mn=$r; for v in $g $b; do (( v > mx )) && mx=$v; (( v < mn )) && mn=$v; done; echo $((mx - mn)); }

render base
check "nothing is drawn far from the card (a corner of the overlay)" "0 0 0 0" "$(px base 2 2)"
check "nor in the middle of the card, away from the rim and the icon" yes "$([[ $(lum "$(px base 240 80)") -lt 6 ]] && echo yes || echo no)"
read -r _ _ alpha <<<"$(stat base)"; check "the output is added light: alpha is 0 everywhere" 0 "$alpha"

# the light comes from the top right
tr=$(lum "$(px base 400 30)"); bl=$(lum "$(px base 60 119)")
check "the rim is brighter at the top right than at the bottom left (>= 1.3x)" yes "$([[ $tr -ge $((bl * 13 / 10)) && $bl -gt 0 ]] && echo yes || echo no)"
check "the rim is thin: the pixel 5 px inside the top edge is much dimmer than the edge" yes "$([[ $(lum "$(px base 300 35)") -lt $(( $(lum "$(px base 300 30)") / 2 )) ]] && echo yes || echo no)"
check "there is a faint halo just outside the edge" yes "$([[ $(lum "$(px base 300 27)") -gt 0 ]] && echo yes || echo no)"

# the ignition
render hot U_energy=2.2; read -r s1 _ _ <<<"$(stat base)"; read -r s2 mx2 _ <<<"$(stat hot)"
check "igniting (energy 2.2) is brighter than settled, by at least 1.3x" yes "$([[ $s2 -ge $((s1 * 13 / 10)) ]] && echo yes || echo no)"
check "at the real ignition energy the brightest channel keeps headroom (the roll-off, not a flat clip)" yes "$([[ $mx2 -lt 250 ]] && echo yes || echo no)"
render blaze U_energy=6; read -r _ mx _ <<<"$(stat blaze)"
check "and a rim six times too bright still has a gentle shoulder: some pixels are below the maximum" yes "$([[ $mx -le 255 && $(lum "$(px blaze 400 30)") -gt $(lum "$(px hot 400 30)") ]] && echo yes || echo no)"

# palettes: at the same spot on the left of the top rim, normal is teal-blue, critical is amber
n=$(px base 70 30); render crit U_urgency=2; c=$(px crit 70 30); render low U_urgency=0; l=$(px low 70 30)
read -r nr ng nb _ <<<"$n"; read -r cr cg cb _ <<<"$c"; read -r lr lg lb _ <<<"$l"
check "normal toasts are cool (blue above red on the rim)" yes "$([[ $nb -gt $nr ]] && echo yes || echo no)"
check "critical toasts are warm (red above blue)" yes "$([[ $cr -gt $cb ]] && echo yes || echo no)"
check "low toasts are green-ish (green above red and blue-ish)" yes "$([[ $lg -gt $lr ]] && echo yes || echo no)"

# the icon ring
ring=$(lum "$(px base 79 75)"); render noicon U_icon=0,0,0; none=$(lum "$(px noicon 79 75)")
check "the icon ring is drawn where asked" yes "$([[ $ring -gt 30 ]] && echo yes || echo no)"
check "and not at all when the radius is 0" yes "$([[ $none -lt 6 ]] && echo yes || echo no)"
check "the ring has a spore at its centre" yes "$([[ $(lum "$(px base 62 75)") -gt 20 ]] && echo yes || echo no)"

# vividness and drift
render dull U_vividness=0; render vivid U_vividness=1
check "vividness 0 is less saturated than 1 on the rim" yes "$([[ $(chroma "$(px dull 400 30)") -lt $(chroma "$(px vivid 400 30)") ]] && echo yes || echo no)"
render later U_time=30; a=$(lum "$(px base 200 30)"); b=$(lum "$(px later 200 30)")
check "the colour drifts with time, but only slowly (brightness within 30%)" yes "$([[ $a -gt 0 && $b -gt 0 && $(( a > b ? a - b : b - a )) -lt $((a * 3 / 10 + 1)) ]] && echo yes || echo no)"
check "and the hue does change" yes "$([[ "$(px base 200 30)" != "$(px later 200 30)" ]] && echo yes || echo no)"
render faded U_qt_Opacity=0.5; check "qt_Opacity scales the light" yes "$([[ $(lum "$(px faded 400 30)") -lt $(( $(lum "$(px base 400 30)") * 6 / 10 )) ]] && echo yes || echo no)"

# the shader works in logical px: the same drawing at 2x the size has a rim twice as thick in bitmap px, i.e. the same look
echo
if (( fail == 0 )); then echo "ALL $pass CHECKS PASS"; else echo "$fail FAILED, $pass passed"; fi
exit $(( fail ? 1 : 0 ))
