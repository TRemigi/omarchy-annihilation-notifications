#!/bin/bash
# Numeric tests of the roots in shaders/toastgrowth.frag (compiled form), run on Mesa's software GL through test/shader-harness.c:
# how far they reach, how many there are, that nothing pops in at the start, that they grow steadily and are still growing in the
# second half of the toast's life, and that they are done just before it ends. (The rim, veins, lichen, ring and countdown are in
# test/growth-test.sh; this file is separate because it needs a bigger overlay and is quick enough to re-run after every tweak.)
# Needs gcc, EGL and GLES headers, llvmpipe, qsb and python3 (standard library only). About a minute.
#
#   bash test/growth-roots-test.sh
#
# `growth` is how far through its life the toast is (0 to 1). The overlay is 440x240 with the card, 300x90, at (130,30): 130 px of
# room on the left and 90 below it.
set -u
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0
check() { if [[ $2 == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: want [$2] got [$3]"; fi; }
yes_if() { [[ $2 == yes ]] && check "$1" yes yes || check "$1" yes no; }

/usr/lib/qt6/bin/qsb -x "glsl,100 es" -o "$tmp/s.frag" "$HERE/shaders/toastgrowth.frag.qsb" || exit 2
gcc -O2 "$HERE/test/shader-harness.c" -o "$tmp/harness" -lEGL -lGLESv2 || exit 2

render() { # out growth seed
  env EGL_PLATFORM=surfaceless LIBGL_ALWAYS_SOFTWARE=1 U_time=3 U_energy=1 U_vividness=0.75 U_urgency=1 U_radius=5 U_seed=$3 U_growth=$2 \
    U_size=440,240 U_card=130,30,300,90 U_icon=0,0,0 U_remaining=-1 U_spores=0 "$tmp/harness" "$tmp/s.frag" 440 240 "$tmp/$1.pam" 2>/dev/null
}
# stats FILE -> "left below runs ink belowink bruns":
#   left    how far left of the card (px) the farthest lit pixel (luminance > 6) is
#   below   how far below the card
#   runs    how many separate lit stretches cross a vertical line 40 px left of the card, over the whole height (roughly, the roots and
#           their shoots on the left: the roots are about 10 px across at the base, so nearer the card they merge)
#   ink     lit pixels (luminance > 10) outside the card and not above it
#   belowink  lit pixels (luminance > 10) in the band below the card
#   bruns   how many separate lit stretches cross a horizontal line 8 px under the card (the roots hanging from the bottom edge)
stats() {
  python3 - "$tmp/$1.pam" <<'PY'
import sys
d = open(sys.argv[1], "rb").read(); e = d.index(b"ENDHDR\n") + 7
def lum(x, y): o = e + (y * 440 + x) * 4; return (299 * d[o] + 587 * d[o + 1] + 114 * d[o + 2]) // 1000
left = next((130 - x for x in range(0, 124) if any(lum(x, y) > 6 for y in range(20, 130))), 0)
below = next((y - 120 for y in range(239, 125, -1) if any(lum(x, y) > 6 for x in range(140, 420))), 0)
runs = 0; inrun = False
for y in range(0, 240):
    v = lum(90, y) > 20
    if v and not inrun: runs += 1
    inrun = v
ink = sum(1 for y in range(240) for x in range(440) if lum(x, y) > 10 and not (130 <= x < 430 and 28 <= y < 122) and not (y < 30 and x >= 130))
belowink = sum(1 for y in range(126, 240) for x in range(130, 430) if lum(x, y) > 10)
bruns = 0; inrun = False
for x in range(135, 425):
    v = lum(x, 128) > 20
    if v and not inrun: bruns += 1
    inrun = v
print(left, below, runs, ink, belowink, bruns)
PY
}

# one toast through its life, and the same roots with three other seeds when it is over
for g in 0 0.04 0.125 0.25 0.5 0.75 0.9 0.985 1; do render "g$g" "$g" 7; done
for s in 41 3 19; do render "s$s" 1 "$s"; done
render e7 0.09 7; render e41 0.09 41
declare -A L B R I BI BR
for g in 0 0.04 0.125 0.25 0.5 0.75 0.9 0.985 1; do read -r L[$g] B[$g] R[$g] I[$g] BI[$g] BR[$g] <<<"$(stats "g$g")"; done
for s in 41 3 19; do read -r L[s$s] B[s$s] R[s$s] I[s$s] BI[s$s] BR[s$s] <<<"$(stats "s$s")"; done
for s in 7 41; do read -r _ _ _ _ _ BR[e$s] <<<"$(stats "e$s")"; done

# how far they reach, for every seed: the left ones about 80 to 95 px (the room is 130), the ones below about 68 to 75 (the room is 120)
for k in 1 s41 s3 s19; do
  yes_if "the roots on the left edge reach their full length (seed $k: ${L[$k]} px, at least 70; the shortest seen is 80) and not past the overlay's margin (at most 112)" "$([[ ${L[$k]} -ge 70 && ${L[$k]} -le 112 ]] && echo yes || echo no)"
  yes_if "the roots below the card reach their full length (seed $k: ${B[$k]} px, at least 58; the shortest seen is 68) and not past the margin (at most 105)" "$([[ ${B[$k]} -ge 58 && ${B[$k]} -le 105 ]] && echo yes || echo no)"
  yes_if "there are several roots on the left edge (seed $k: ${R[$k]} crossing a line 40 px out; between 3 and 9)" "$([[ ${R[$k]} -ge 3 && ${R[$k]} -le 9 ]] && echo yes || echo no)"
done

# nothing pops in: at the very start (4% of the life) nothing has appeared; it takes more than a moment to get going
check "at 4% of the life nothing has grown yet, left or below (it eases in, and the roots start a little apart)" "0 0" "${L[0.04]} ${B[0.04]}"
yes_if "and the ink is the border's own, no more (within 25 pixels of what it is at 0%: ${I[0.04]} against ${I[0]})" "$([[ ${I[0.04]} -le $(( ${I[0]} + 25 )) ]] && echo yes || echo no)"

# growth is steady and does not go backward
prev=-1; ok=yes
for g in 0.125 0.25 0.5 0.75 0.9 0.985 1; do [[ ${L[$g]} -ge $prev ]] || ok=no; prev=${L[$g]}; done
yes_if "the reach on the left never goes back as the life goes on" "$ok"
prev=-1; ok=yes
for g in 0.125 0.25 0.5 0.75 0.9 0.985 1; do [[ ${B[$g]} -ge $prev ]] || ok=no; prev=${B[$g]}; done
yes_if "nor the reach below" "$ok"
yes_if "they grow quickly at first: a quarter of the way through the life they are a good way out (left reach at 25% at least 35% of the final)" "$([[ $(( ${L[0.25]} * 100 )) -ge $(( ${L[1]} * 35 )) ]] && echo yes || echo no)"
yes_if "the roots start at different moments, below the card too: at 9% of the life at most 35% of the hanging roots are out (seed 7: ${BR[e7]} of ${BR[1]}; seed 41: ${BR[e41]} of ${BR[s41]}), and there are at least 5 of them by the end" "$([[ $(( ${BR[e7]} * 100 )) -le $(( ${BR[1]} * 35 )) && $(( ${BR[e41]} * 100 )) -le $(( ${BR[s41]} * 35 )) && ${BR[1]} -ge 5 ]] && echo yes || echo no)"
yes_if "the roots start at different moments: at 12.5% of the life at most ${R[1]}-2 of the roots on the left are out (${R[0.125]} are; all ${R[1]} are by the end)" "$([[ ${R[0.125]} -le $(( ${R[1]} - 2 )) ]] && echo yes || echo no)"
yes_if "but not all at once: the left reach at 12.5% is under 40% of the final" "$([[ $(( ${L[0.125]} * 100 )) -lt $(( ${L[1]} * 40 )) ]] && echo yes || echo no)"

# the second half of the life still shows growth (the roots seemed finished at about 40% of the life until the shoots were added)
net() { echo $(( ($1 - ${I[0]}) * 1000 / (${I[1]} - ${I[0]}) )); }   # the share of the final root ink, in tenths of a percent
yes_if "after half the life at least 20% of the root ink is still to come (it is $(( 1000 - $(net ${I[0.5]}) )) per mille)" "$([[ $(net ${I[0.5]}) -le 800 ]] && echo yes || echo no)"
yes_if "after three quarters at least 5% is still to come ($(( 1000 - $(net ${I[0.75]}) )) per mille)" "$([[ $(net ${I[0.75]}) -le 950 ]] && echo yes || echo no)"
yes_if "at 90% of the life they are still growing (at least 0.5% still to come: $(( 1000 - $(net ${I[0.9]}) )) per mille)" "$([[ $(net ${I[0.9]}) -le 995 ]] && echo yes || echo no)"
yes_if "and they are done, or all but, just before the end (98.5% of the life: within 1% of the final)" "$([[ $(net ${I[0.985]}) -ge 990 ]] && echo yes || echo no)"

# the roots below
yes_if "there is nothing below the card at 0% and a good deal at 100% (the roots hang from the bottom edge)" "$([[ ${BI[0]} -eq 0 && ${BI[1]} -ge 1000 ]] && echo yes || echo no)"

echo "growth-roots-test: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
