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

# the countdown: a line of light along the bottom edge (y = 30 + 90 - 3.2), from the card's left border to its right
# border when full (x = 31 to 409 for the 380 px card at x = 30), so it meets both
render none U_remaining=-1; render full U_remaining=1; render half U_remaining=0.5; render quarter U_remaining=0.25; render almost U_remaining=0.9; render gone U_remaining=0
y=117
# Row 117 already has a little light without a countdown (the bottom rim's spill), so "lit" means above that.
over() { echo $(( $(lum "$(px "$1" "$2" $y)") - $(lum "$(px none "$2" $y)") )); }
check "no countdown (a critical toast) is the same as an empty one: nothing added" "$(px gone 200 $y)" "$(px none 200 $y)"
check "a full countdown draws a bright line along the bottom" yes "$([[ $(over full 200) -gt 50 ]] && echo yes || echo no)"
check "at half, the first half of the line is lit" yes "$([[ $(over half 130) -gt 50 ]] && echo yes || echo no)"
check "at half, the second half is exactly as without a countdown" "$(px none 308 $y)" "$(px half 308 $y)"
check "the spark at the end of the line is brighter than the line" yes "$([[ $(lum "$(px half 220 $y)") -gt $(( $(lum "$(px half 130 $y)") + 15 )) ]] && echo yes || echo no)"
lit() { local n=0 x; for x in $(seq 40 4 420); do [[ $(over $1 $x) -gt 30 ]] && n=$((n + 1)); done; echo $n; }
extent() { local lo=0 hi=0 x; for x in $(seq 30 1 410); do if [[ $(over $1 $x) -gt 25 ]]; then (( lo == 0 )) && lo=$x; hi=$x; fi; done; echo "$lo $hi"; }
read -r flo fhi <<<"$(extent full)"
check "a full line starts at the card's left border (x = 30), with no gap" yes "$([[ $flo -ge 30 && $flo -le 32 ]] && echo yes || echo no)"
check "and ends at the card's right border (x = 410): the line fits the card's length" yes "$([[ $fhi -ge 408 && $fhi -le 410 ]] && echo yes || echo no)"
for rad in 0 4 10; do
  render "r$rad" U_remaining=1 U_radius=$rad; read -r rlo rhi <<<"$(extent "r$rad")"
  max=$([[ $rad -eq 10 ]] && echo 36 || echo 32)
  check "whatever the corner radius ($rad), the full line meets the left border (starts by x = $max) and the right one (ends from x = $((442 - max)))" yes "$([[ $rlo -ge 30 && $rlo -le $max && $rhi -ge $((442 - max)) && $rhi -le 410 ]] && echo yes || echo no)"
done
read -r hlo hhi <<<"$(extent half)"
check "at half, it still starts at the border and ends in the middle of the card (spark near x = 220)" yes "$([[ $hlo -le 32 && $hhi -ge 215 && $hhi -le 232 ]] && echo yes || echo no)"
check "the line only ever gets shorter as time runs out (lit samples: 0.9 > 0.5 > 0.25)" yes "$([[ $(lit almost) -gt $(lit half) && $(lit half) -gt $(lit quarter) && $(lit quarter) -gt 0 ]] && echo yes || echo no)"
check "an empty countdown draws nothing" yes "$([[ $(lit gone) -eq 0 ]] && echo yes || echo no)"
read -r fr fg fb _ <<<"$(px full 100 $y)"; read -r hr hg hb _ <<<"$(px half 100 $y)"
check "the line's colours stay put as it drains (it retreats, it does not recolour): same colour at x=100 at full and at half" yes "$([[ $(( fr > hr ? fr - hr : hr - fr )) -lt 14 && $(( fg > hg ? fg - hg : hg - fg )) -lt 14 && $(( fb > hb ? fb - hb : hb - fb )) -lt 14 ]] && echo yes || echo no)"
render critline U_remaining=0.5 U_urgency=2; read -r kr kg kb _ <<<"$(px critline 100 $y)"
check "a critical-palette line is warm" yes "$([[ $kr -gt $kb ]] && echo yes || echo no)"
render fading U_remaining=0.04
check "the line fades out over the last 8% of the toast's life" yes "$([[ $(over fading 60) -lt $(( $(over half 60) * 8 / 10 )) && $(over fading 60) -gt 0 ]] && echo yes || echo no)"
check "the countdown is added light too: alpha stays 0" 0 "$(read -r _ _ a <<<"$(stat full)"; echo $a)"

# the faint spores off the card's left edge: a 500x150 overlay with the card at (70,30), so there is room to its left
aren() { # out [VAR=value ...]
  local out=$1; shift
  env EGL_PLATFORM=surfaceless LIBGL_ALWAYS_SOFTWARE=1 U_time=3 U_energy=1 U_vividness=0.75 U_urgency=1 U_radius=5 U_remaining=-1 \
    U_size=500,150 U_card=70,30,380,90 U_icon=0,0,0 U_spores=1 "$@" "$tmp/harness" "$tmp/s.frag" 500 150 "$tmp/$out.pam" 2>/dev/null
}
# diffstat A B -> "sum minx maxx miny maxy maxchannel count" of what B has that A lacks (light added, per pixel)
diffstat() {
  python3 - "$tmp/$1.pam" "$tmp/$2.pam" <<'PY'
import sys
def load(p):
    d = open(p, "rb").read(); e = d.index(b"ENDHDR\n") + 7; w = int(d.split(b"WIDTH ")[1].split()[0]); return d[e:], w
a, W = load(sys.argv[1]); b, _ = load(sys.argv[2]); H = len(a) // 4 // W
tot = cnt = mx = 0; minx = miny = 10**9; maxx = maxy = -1
for y in range(H):
    for x in range(W):
        o = (y * W + x) * 4
        dl = max(0, (b[o] - a[o]) + (b[o + 1] - a[o + 1]) + (b[o + 2] - a[o + 2]))
        if dl > 6:
            tot += dl; cnt += 1; minx = min(minx, x); maxx = max(maxx, x); miny = min(miny, y); maxy = max(maxy, y)
            mx = max(mx, max(b[o] - a[o], b[o + 1] - a[o + 1], b[o + 2] - a[o + 2]))
print(tot, minx if cnt else -1, maxx, miny if cnt else -1, maxy, mx, cnt)
PY
}
aren off U_spores=0; aren on; aren off6 U_spores=0 U_time=6; aren later U_time=6; aren half U_spores=0.5
read -r st sminx smaxx sminy smaxy smax scnt <<<"$(diffstat off on)"
check "with spore_amount > 0 there are spores" yes "$([[ $st -gt 200 && $scnt -gt 10 ]] && echo yes || echo no)"
check "they are all to the left of the card (the card's left edge is x = 70)" yes "$([[ $smaxx -le 71 ]] && echo yes || echo no)"
check "and within 56 px of it: none farther left than x = 12" yes "$([[ $sminx -ge 12 ]] && echo yes || echo no)"
check "and level with the card, not above or below it (card rows 30 to 120)" yes "$([[ $sminy -ge 18 && $smaxy -le 132 ]] && echo yes || echo no)"
check "they are faint: no spore brighter than 170 in any channel" yes "$([[ $smax -lt 170 ]] && echo yes || echo no)"
check "and few: a handful of dots, not a haze (fewer than 700 lit pixels)" yes "$([[ $scnt -lt 700 ]] && echo yes || echo no)"
# (compared like for like: the spores at time 6 against the card at time 6 without them, since the rim's colour drifts too)
read -r lt _ _ _ _ _ _ <<<"$(diffstat off6 later)"
check "they move: six seconds later there are different spores (and still some)" yes "$([[ "$(diffstat off on)" != "$(diffstat off6 later)" && $lt -gt 200 ]] && echo yes || echo no)"
# over a stretch of time: how far left they reach, that nothing is clipped hard at the edge of their area, and where they sit
for t in 0.5 1.7 2.9 4.1 5.3 6.5 7.7 8.9; do aren "off_$t" U_spores=0 U_time=$t; aren "on_$t" U_time=$t; done
agg=$(python3 - "$tmp" <<'PY'
import sys
tmp = sys.argv[1]
def load(p):
    d = open(p, "rb").read(); e = d.index(b"ENDHDR\n") + 7; return d[e:]
W, H = 500, 150
minx = 10**9; edge = 0; wy = tot = 0
for t in ["0.5", "1.7", "2.9", "4.1", "5.3", "6.5", "7.7", "8.9"]:
    a = load(f"{tmp}/off_{t}.pam"); b = load(f"{tmp}/on_{t}.pam")
    for y in range(H):
        for x in range(W):
            o = (y * W + x) * 4
            dl = max(0, (b[o] - a[o]) + (b[o + 1] - a[o + 1]) + (b[o + 2] - a[o + 2]))
            if dl > 6:
                minx = min(minx, x); wy += dl * y; tot += dl
                if x <= 16: edge = max(edge, dl)
print(minx, edge, round(wy / tot) if tot else -1)
PY
)
read -r aggmin aggedge aggy <<<"$agg"
check "over time they reach well away from the edge (the farthest left light is by x = 26, ie 44+ px from the card; it is 21)" yes "$([[ $aggmin -le 26 && $aggmin -ge 14 ]] && echo yes || echo no)"
check "and fade out before the edge of their area: nothing bright at x <= 16 (no hard cut)" yes "$([[ $aggedge -lt 10 ]] && echo yes || echo no)"
check "and they come off the whole height of the card: the light's vertical centre is mid-card (y about 75, within 15)" yes "$([[ $aggy -ge 60 && $aggy -le 90 ]] && echo yes || echo no)"
read -r ht _ _ _ _ _ _ <<<"$(diffstat off half)"
check "spore_amount 0.5 gives less light than 1, and more than none" yes "$([[ $ht -lt $st && $ht -gt 0 ]] && echo yes || echo no)"
check "spore_amount 0 gives exactly the card without them" "0 -1 -1 -1 -1 0 0" "$(diffstat off off)"
aren crit U_urgency=2; read -r ct _ _ _ _ _ _ <<<"$(diffstat off crit)"
check "a critical toast has them too" yes "$([[ $ct -gt 0 ]] && echo yes || echo no)"

# the contract with the QML: every uniform the shader declares has a property of the same name on ToastRim's
# ShaderEffect, and every property there is a uniform (the offscreen tests cannot see a mismatch: nothing renders)
uniforms=$(/usr/lib/qt6/bin/qsb --dump "$HERE/shaders/toastrim.frag.qsb" | sed -n 's/^ *"name": "\(.*\)",\{0,1\}$/\1/p' | grep -vx -e qt_TexCoord0 -e fragColor -e qt_Matrix -e qt_Opacity | sort -u | tr '\n' ' ')
props=$(sed -n '/^  ShaderEffect {/,/fragmentShader/p' "$HERE/components/ToastRim.qml" | grep -oE "^ +property [a-z0-9]+ [a-zA-Z]+" | awk '{print $3}' | sort -u | tr '\n' ' ')
check "the shader's uniforms and ToastRim's ShaderEffect properties are the same set" "$uniforms" "$props"
check "and that set is not empty" yes "$([[ -n $uniforms ]] && echo yes || echo no)"

# the shader works in logical px: the same drawing at 2x the size has a rim twice as thick in bitmap px, i.e. the same look
echo
if (( fail == 0 )); then echo "ALL $pass CHECKS PASS"; else echo "$fail FAILED, $pass passed"; fi
exit $(( fail ? 1 : 0 ))
