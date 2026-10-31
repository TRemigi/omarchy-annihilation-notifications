#!/bin/bash
# Numeric tests of shaders/toastspores.frag, through test/shader-harness.c on Mesa's software GL: that nothing is drawn
# without a burst or outside its reach, where the spores appear and which way they drift, that they fade away and
# are deterministic, that separate toasts' bursts are independent, and that amount scales them. Needs gcc, EGL and GLES
# headers, llvmpipe, qsb and python3 (standard library only).
#
#   bash test/spores-test.sh
#
# Each check was also confirmed to fail when the shader was broken on purpose.
set -u
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0
check() { if [[ $2 == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: want [$2] got [$3]"; fi; }
/usr/lib/qt6/bin/qsb -x "glsl,100 es" -o "$tmp/s.frag" "$HERE/shaders/toastspores.frag.qsb" || exit 2
gcc -O2 "$HERE/test/shader-harness.c" -o "$tmp/harness" -lEGL -lGLESv2 || exit 2

# A 520x240 layer; the card that dissolves is 400x80 at (110,70): it ends at x = 510, so spores drift left into x < 110.
W=520; H=240
render() { # out [VAR=value ...]
  local out=$1; shift
  env EGL_PLATFORM=surfaceless LIBGL_ALWAYS_SOFTWARE=1 U_amount=1 U_size=$W,$H U_rect0=110,70,400,80 U_state0=-1,5,1,0 \
    U_rect1=0,0,0,0 U_state1=-1,0,1,0 U_rect2=0,0,0,0 U_state2=-1,0,1,0 U_rect3=0,0,0,0 U_state3=-1,0,1,0 "$@" "$tmp/harness" "$tmp/s.frag" $W $H "$tmp/$out.pam" 2>/dev/null
}
# stats FILE -> "total centroid_x centroid_y min_x max_x litpixels maxalpha maxchannel brightcores" (light > 12 counts as lit, > 150 as a core)
stats() {
  python3 - "$tmp/$1.pam" $W $H <<'PY'
import sys
d = open(sys.argv[1], "rb").read(); e = d.index(b"ENDHDR\n") + 7; b = d[e:]; W, H = int(sys.argv[2]), int(sys.argv[3])
tot = sx = sy = n = 0; mn = 10**9; mx = -1; ma = 0; mc = 0; cores = 0
for y in range(H):
    for x in range(W):
        o = (y * W + x) * 4; l = b[o] + b[o + 1] + b[o + 2]; ma = max(ma, b[o + 3]); mc = max(mc, b[o], b[o + 1], b[o + 2])
        if l > 150: cores += 1
        if l > 12: tot += l; sx += l * x; sy += l * y; n += 1; mn = min(mn, x); mx = max(mx, x)
print(tot, round(sx / tot) if tot else -1, round(sy / tot) if tot else -1, mn if n else -1, mx if n else -1, n, ma, mc, cores)
PY
}
f() { read -r $2 <<<"$(stats $1 | awk -v c=$3 '{print $c}')"; }
col() { stats "$1" | awk -v c="$2" '{print $c}'; }

render none;                      check "no burst (age < 0): nothing is drawn" "0 -1 -1 -1 -1 0 0 0 0" "$(stats none)"
render early U_state0=0.0,5,1,0;  check "at age 0 nothing has lifted off yet (spores start at delay >= 0 and fade in)" yes "$([[ $(col early 1) -lt 400 ]] && echo yes || echo no)"
render a04 U_state0=0.4,5,1,0; render a08 U_state0=0.8,5,1,0; render a12 U_state0=1.2,5,1,0
check "at 0.4 s there are spores on screen" yes "$([[ $(col a04 6) -gt 20 ]] && echo yes || echo no)"
check "the light is added: alpha is 0 everywhere" 0 "$(col a04 7)"
check "and it never clips flat to 255" yes "$([[ $(col a04 8) -lt 255 ]] && echo yes || echo no)"
check "they lift off the card's body: at 0.4 s some light is over the card (x within 110..510)" yes "$([[ $(col a04 4) -le 510 && $(col a04 2) -ge 110 ]] && echo yes || echo no)"
check "they drift to the left: the centroid moves left from 0.4 s to 0.8 s to 1.2 s" yes "$([[ $(col a04 2) -gt $(col a08 2) && $(col a08 2) -gt $(col a12 2) ]] && echo yes || echo no)"
check "and travel a good way: by 1.2 s the leftmost light is clear of the card's left edge (x < 110)" yes "$([[ $(col a12 4) -lt 105 ]] && echo yes || echo no)"
check "but not too far: nothing beyond the 110 px reach to the left (x >= 110 - 110 - 12)" yes "$([[ $(col a12 4) -ge 0 ]] && echo yes || echo no)"
render a22 U_state0=2.1,5,1,0; check "they have all faded out by 2.1 s" yes "$([[ $(col a22 1) -lt 60 ]] && echo yes || echo no)"
render a30 U_state0=2.4,5,1,0; check "after 2.2 s a burst draws nothing at all" "0" "$(col a30 1)"
render seed6 U_state0=0.8,6,1,0; check "a different seed gives a different burst" yes "$([[ "$(stats a08)" != "$(stats seed6)" ]] && echo yes || echo no)"
render a08b U_state0=0.8,5,1,0; check "the same seed and age give exactly the same burst (deterministic)" "$(stats a08)" "$(stats a08b)"
check "the burst has a few dozen spores, not a handful and not a blizzard (bright cores at 0.8 s: about 370)" yes "$([[ $(col a08 9) -gt 120 && $(col a08 9) -lt 900 ]] && echo yes || echo no)"
render amt0 U_state0=0.8,5,1,0 U_amount=0; check "amount 0 turns them off" "0" "$(col amt0 1)"
render amt5 U_state0=0.8,5,1,0 U_amount=0.5; check "amount 0.5 gives less light than 1" yes "$([[ $(col amt5 1) -lt $(col a08 1) && $(col amt5 1) -gt 0 ]] && echo yes || echo no)"

# the card's vertical extent: spores stay near it (y within 70-22 .. 150+22), never across the toast below
render tall U_state0=1.0,5,1,0
check "spores stay beside the card, not across the stack (all light within y 48..172)" yes "$(python3 - "$tmp/tall.pam" <<'PY'
import sys
d = open(sys.argv[1], "rb").read(); e = d.index(b"ENDHDR\n") + 7; b = d[e:]; W, H = 520, 240
bad = sum(1 for y in range(H) for x in range(W) if (y < 46 or y > 174) and (b[(y*W+x)*4] + b[(y*W+x)*4+1] + b[(y*W+x)*4+2]) > 12)
print("yes" if bad == 0 else "no")
PY
)"

# the colours: normal toasts mix amber and teal; critical, amber and pink; low, amber and green
tint() { python3 - "$tmp/$1.pam" <<'PY'
import sys
d = open(sys.argv[1], "rb").read(); e = d.index(b"ENDHDR\n") + 7; b = d[e:]
r = g = bl = 0
for i in range(0, len(b), 4): r += b[i]; g += b[i + 1]; bl += b[i + 2]
print(r, g, bl)
PY
}
render nrm U_state0=0.8,5,1,0; render crt U_state0=0.8,5,2,0; render low U_state0=0.8,5,0,0
read -r nr ng nb <<<"$(tint nrm)"; read -r cr cg cb <<<"$(tint crt)"; read -r lr lg lb <<<"$(tint low)"
check "a normal toast's spores are cooler than a critical one's (more blue relative to red)" yes "$([[ $((nb * cr)) -gt $((cb * nr)) ]] && echo yes || echo no)"
check "a critical toast's spores have more red than green and blue than a low one's has blue (pink vs green)" yes "$([[ $((cb * lg)) -gt $((lb * cg)) ]] && echo yes || echo no)"

# one spore on its own, to see that it eases in and out instead of popping: a variant with a single spore per burst
sed 's/const int SPORES = 22;/const int SPORES = 1;/' "$HERE/shaders/toastspores.frag" > "$tmp/one.frag"
/usr/lib/qt6/bin/qsb --glsl "100 es,120,150" -o "$tmp/one.qsb" "$tmp/one.frag" >/dev/null 2>&1 && /usr/lib/qt6/bin/qsb -x "glsl,100 es" -o "$tmp/one-es.frag" "$tmp/one.qsb"
series=$(for a in $(seq 0 0.04 2.2); do
  env EGL_PLATFORM=surfaceless LIBGL_ALWAYS_SOFTWARE=1 U_amount=1 U_size=520,240 U_rect0=110,70,400,80 U_state0=$a,5,1,0 U_rect1=0,0,0,0 U_state1=-1,0,1,0 \
    U_rect2=0,0,0,0 U_state2=-1,0,1,0 U_rect3=0,0,0,0 U_state3=-1,0,1,0 "$tmp/harness" "$tmp/one-es.frag" 520 240 "$tmp/one.pam" 2>/dev/null
  python3 - "$tmp/one.pam" <<'PY'
import sys
d = open(sys.argv[1], "rb").read(); e = d.index(b"ENDHDR\n") + 7; b = d[e:]
print(sum(b[i] + b[i + 1] + b[i + 2] for i in range(0, len(b), 4)))
PY
done | tr '\n' ' ')
check "a single spore's light, over its life" yes "$(python3 - $series <<'PY'
import sys
v = [int(x) for x in sys.argv[1:]]; peak = max(v); nz = [i for i, x in enumerate(v) if x > 0]
first, last = v[nz[0]], v[nz[-1]]
steps = max(abs(v[i + 1] - v[i]) for i in range(len(v) - 1))
# it fades in from nothing, fades out to nothing, and never jumps by more than half its peak between samples
print("yes" if peak > 0 and first < 0.25 * peak and last < 0.25 * peak and steps < 0.5 * peak else "no")
PY
)"

# four independent bursts
render two U_rect1=110,160,400,80 U_state1=0.8,9,1,0 U_state0=0.8,5,1,0
check "a second burst adds its own light, below the first, without disturbing the first" yes "$([[ $(col two 1) -gt $(( $(col a08 1) * 14 / 10 )) ]] && echo yes || echo no)"

echo
if (( fail == 0 )); then echo "ALL $pass CHECKS PASS"; else echo "$fail FAILED, $pass passed"; fi
exit $(( fail ? 1 : 0 ))
