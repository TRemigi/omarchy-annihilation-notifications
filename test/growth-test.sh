#!/bin/bash
# Numeric tests of shaders/toastgrowth.frag (compiled form), run on Mesa's software GL through test/shader-harness.c, as
# test/shader-test.sh does for the rim: where it draws, that the veins grow out and stay on the left and the corners, the lichen
# hugging the left edge, the seed, the countdown, the palettes and the ring, and that ToastRim feeds it exactly its uniforms.
#
#   bash test/growth-test.sh
#
# Each check was also confirmed to fail when the shader was broken on purpose.
set -u
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0
check() { if [[ $2 == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: want [$2] got [$3]"; fi; }
yes_if() { [[ $2 == yes ]] && check "$1" yes yes || check "$1" yes no; }

/usr/lib/qt6/bin/qsb -x "glsl,100 es" -o "$tmp/s.frag" "$HERE/shaders/toastgrowth.frag.qsb" || exit 2
gcc -O2 "$HERE/test/shader-harness.c" -o "$tmp/harness" -lEGL -lGLESv2 || exit 2

# A 440x150 overlay, the card 380x90 at (30,30), its radius 5, an icon ring of radius 17 at (62,75). Settled, no countdown.
render() { # out [VAR=value ...]
  local out=$1; shift
  env EGL_PLATFORM=surfaceless LIBGL_ALWAYS_SOFTWARE=1 U_time=3 U_energy=1 U_vividness=0.75 U_urgency=1 U_radius=5 U_seed=7 U_growth=1 \
    U_size=440,150 U_card=30,30,380,90 U_icon=62,75,17 U_remaining=-1 U_spores=0 "$@" "$tmp/harness" "$tmp/s.frag" 440 150 "$tmp/$out.pam" 2>/dev/null
}
# px FILE X Y -> "r g b a"
px() {
  python3 - "$tmp/$1.pam" "$2" "$3" <<'PY'
import sys
d = open(sys.argv[1], "rb").read(); e = d.index(b"ENDHDR\n") + 7
x, y = int(sys.argv[2]), int(sys.argv[3]); o = e + (y * 440 + x) * 4
print(*d[o:o + 4])
PY
}
# rsum FILE X0 Y0 X1 Y1 -> the sum of r+g+b over the rectangle [X0,X1) x [Y0,Y1)
rsum() {
  python3 - "$tmp/$1.pam" "$2" "$3" "$4" "$5" <<'PY'
import sys
d = open(sys.argv[1], "rb").read(); e = d.index(b"ENDHDR\n") + 7
x0, y0, x1, y1 = map(int, sys.argv[2:6]); t = 0
for y in range(y0, y1):
    for x in range(x0, x1):
        o = e + (y * 440 + x) * 4; t += d[o] + d[o + 1] + d[o + 2]
print(t)
PY
}
maxlum() { python3 - "$tmp/$1.pam" "$2" "$3" "$4" "$5" <<'PY'
import sys
d = open(sys.argv[1], "rb").read(); e = d.index(b"ENDHDR\n") + 7
x0, y0, x1, y1 = map(int, sys.argv[2:6]); m = 0
for y in range(y0, y1):
    for x in range(x0, x1):
        o = e + (y * 440 + x) * 4; m = max(m, (299 * d[o] + 587 * d[o + 1] + 114 * d[o + 2]) // 1000)
print(m)
PY
}
maxalpha() { python3 - "$tmp/$1.pam" <<'PY'
import sys
d = open(sys.argv[1], "rb").read(); e = d.index(b"ENDHDR\n") + 7; print(max(d[e + 3::4]))
PY
}
lum() { read -r r g b a <<<"$1"; echo $(( (299 * r + 587 * g + 114 * b) / 1000 )); }
chroma() { read -r r g b a <<<"$1"; local mx=$r mn=$r; for v in $g $b; do (( v > mx )) && mx=$v; (( v < mn )) && mn=$v; done; echo $((mx - mn)); }
gt() { [[ $1 -gt $2 ]] && echo yes || echo no; }

render base
check "nothing is drawn in a far corner of the overlay" "0 0 0 0" "$(px base 2 2)"
check "the output is added light: alpha is 0 everywhere" 0 "$(maxalpha base)"
yes_if "the middle of the card, away from the rim, lichen and icon, is dark" "$([[ $(lum "$(px base 240 80)") -lt 6 ]] && echo yes || echo no)"
yes_if "the outline is drawn: the top edge is lit" "$(gt "$(rsum base 100 29 300 33)" 3000)"
yes_if "the outline is thin: five px inside the top edge it is dim" "$([[ $(rsum base 100 35 300 36) -lt $(( $(rsum base 100 30 300 31) / 3 )) ]] && echo yes || echo no)"

# the veins: none at growth 0, out on the left and in at the right corners at growth 1, in between at half
render g0 U_growth=0; render g5 U_growth=0.5
left() { rsum "$1" 0 0 18 150; }   # the card's own halo reaches only ~10 px out of its edge, so the veins are measured beyond that
yes_if "at growth 0 there are no veins in the free space on the left" "$([[ $(( $(left g0) * 8 )) -lt $(left base) ]] && echo yes || echo no)"
yes_if "at growth 1 there are, reaching out to the left of the card" "$(gt "$(left base)" $(( $(left g0) + 3000 )))"
yes_if "at growth 0.5 there are some, fewer than at 1" "$([[ $(left g5) -gt $(left g0) && $(left g5) -lt $(left base) ]] && echo yes || echo no)"
yes_if "they also reach into the card from its right corners (growth 1 against 0)" "$(gt "$(rsum base 360 31 409 60)" $(( $(rsum g0 360 31 409 60) + 1500 )))"
yes_if "they fade toward their tips: brighter 9 to 18 px out than 0 to 9 px out" "$(gt "$(rsum base 9 0 18 150)" "$(rsum base 0 0 9 150)")"
yes_if "and none run along the bottom outside the card (growth 1, 18 px below the lower edge)" "$([[ $(rsum base 100 138 400 150) -lt 600 ]] && echo yes || echo no)"

# the seed: every toast grows differently, and the same seed grows the same
render s2 U_seed=41; render s1b U_seed=7
check "the same seed draws exactly the same" "$(px base 20 40) $(px base 12 118)" "$(px s1b 20 40) $(px s1b 12 118)"
yes_if "another seed draws different veins" "$([[ $(left base) != $(left s2) ]] && echo yes || echo no)"

# lichen: dots on the left, inside the card, thinning inward; none further in
render lich U_growth=0 U_icon=0,0,0
yes_if "lichen: some dot just inside the left edge (x 34 to 46) is bright" "$(gt "$(maxlum lich 34 34 46 116)" 60)"
yes_if "but the band further in (x 60 to 120) has nothing as bright" "$([[ $(maxlum lich 60 40 120 110) -lt 30 ]] && echo yes || echo no)"

# the ignition and the roll-off
render hot U_energy=2.2; render blaze U_energy=6
yes_if "igniting is brighter than settled, by at least 1.3x" "$([[ $(rsum hot 0 0 440 150) -ge $(( $(rsum base 0 0 440 150) * 13 / 10 )) ]] && echo yes || echo no)"
yes_if "and a blaze keeps a shoulder: brighter than the ignition, never past 255" "$(gt "$(lum "$(px blaze 200 30)")" "$(lum "$(px hot 200 30)")")"

# palettes: normal is moss and teal (green above red), critical is warm, low is green
render crit U_urgency=2; render low U_urgency=0
read -r nr ng nb _ <<<"$(px base 200 30)"; read -r cr cg cb _ <<<"$(px crit 200 30)"; read -r lr lg lb _ <<<"$(px low 200 30)"
yes_if "normal toasts are living green-teal (green above red)" "$(gt $ng $nr)"
yes_if "critical toasts are warm (red above blue and above green)" "$([[ $cr -gt $cb && $cr -ge $cg ]] && echo yes || echo no)"
yes_if "low toasts are green (green above red and blue)" "$([[ $lg -gt $lr && $lg -gt $lb ]] && echo yes || echo no)"
render dull U_vividness=0
yes_if "vividness 0 is less saturated than 0.75 on the rim" "$([[ $(chroma "$(px dull 200 30)") -lt $(chroma "$(px base 200 30)") ]] && echo yes || echo no)"

# the icon ring
render noicon U_icon=0,0,0
yes_if "the icon ring is drawn where asked (the spore at its centre)" "$(gt "$(lum "$(px base 62 75)")" 20)"
yes_if "and so is the ring itself, at its radius (within a pixel of it, to the right of the spore)" "$(gt "$(maxlum base 78 74 82 77)" 40)"
yes_if "and not at all when the radius is 0" "$([[ $(lum "$(px noicon 62 75)") -lt 6 ]] && echo yes || echo no)"
yes_if "the ring is a ring: dark between the spore and the ring" "$([[ $(lum "$(px base 62 66)") -lt $(lum "$(px base 62 75)") ]] && echo yes || echo no)"

# the countdown: a vein along the bottom, border to border, retreating from the right; none when negative
render cfull U_remaining=1; render chalf U_remaining=0.5; render cnone U_remaining=-1
bottom() { rsum "$1" 31 114 409 118; }
yes_if "a fresh toast has a line along the bottom, from edge to edge (the far right is lit)" "$(gt "$(rsum cfull 380 114 409 118)" $(( $(rsum cnone 380 114 409 118) + 800 )))"
yes_if "at half life the right half is gone and the left half still lit" "$([[ $(rsum chalf 300 114 409 118) -lt $(( $(rsum cnone 300 114 409 118) + 400 )) && $(rsum chalf 40 114 200 118) -gt $(( $(rsum cnone 40 114 200 118) + 800 )) ]] && echo yes || echo no)"
yes_if "the line ends in a bud: the brightest pixel near its end is whiter than the line" "$(gt "$(rsum chalf 218 113 224 119)" "$(rsum chalf 150 113 156 119)")"
render cdone U_remaining=0
yes_if "at 0 it has gone" "$([[ $(bottom cdone) -le $(( $(bottom cnone) + 200 )) ]] && echo yes || echo no)"

# the spores off the left edge scale with `spores`
render sp1 U_spores=1
yes_if "the faint spores add light to the left of the card, and spores 0 adds none" "$(gt "$(rsum sp1 0 0 29 150)" "$(rsum base 0 0 29 150)")"

# the contract with the QML: the shader declares exactly the properties of ToastRim's ShaderEffect
uniforms=$(/usr/lib/qt6/bin/qsb --dump "$HERE/shaders/toastgrowth.frag.qsb" | sed -n 's/^ *"name": "\(.*\)",\{0,1\}$/\1/p' | grep -vx -e qt_TexCoord0 -e fragColor -e qt_Matrix -e qt_Opacity | sort -u | tr '\n' ' ')
props=$(sed -n '/^  ShaderEffect {/,/fragmentShader/p' "$HERE/components/ToastRim.qml" | grep -oE "^ +property [a-z0-9]+ [a-zA-Z]+" | awk '{print $3}' | sort -u | tr '\n' ' ')
check "the shader's uniforms and ToastRim's ShaderEffect properties are the same set" "$uniforms" "$props"
rimuniforms=$(/usr/lib/qt6/bin/qsb --dump "$HERE/shaders/toastrim.frag.qsb" | sed -n 's/^ *"name": "\(.*\)",\{0,1\}$/\1/p' | grep -vx -e qt_TexCoord0 -e fragColor -e qt_Matrix -e qt_Opacity | sort -u | tr '\n' ' ')
check "and the rim shader declares the same set, so either can be swapped in" "$uniforms" "$rimuniforms"

echo "growth-test: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
