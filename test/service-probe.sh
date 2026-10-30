#!/bin/bash
# Runs the REAL Service.qml in an offscreen Quickshell and checks that the toast motion is gated on the
# theme, switches live when the theme file changes, honours motion_slowdown, and that the setting parser
# behaves. The layer-shell PanelWindow does not exist offscreen, so the test works on a copy in which only
# that window type is swapped for a plain one (and a few debug lines are added to SlotMotion); the
# delegate, the gate and SlotMotion are otherwise exactly what ships.
#
#   bash test/service-probe.sh
#
# Needs quickshell. Takes about 20 seconds.
set -u
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
OMARCHY=${OMARCHY_ROOT:-/usr/share/omarchy}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0
check() { if [[ $2 == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: want [$2] got [$3]"; fi; }
has() { if [[ $3 == *"$2"* ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: output lacks [$2]"; fi; }

# The config root: Omarchy's shell tree (for qs.Commons and qs.Ui), our test shell.qml, and the patched fork.
cfg=$tmp/cfg; mkdir -p "$cfg/fork/components"
for e in "$OMARCHY"/shell/*; do b=$(basename "$e"); [[ $b == shell.qml || $b == plugins ]] || ln -s "$e" "$cfg/$b"; done
cp "$HERE/test/service-probe/shell.qml" "$cfg/shell.qml"
cp "$HERE/Service.qml" "$HERE/NotificationLogic.js" "$cfg/fork/"; cp "$HERE"/components/*.qml "$cfg/fork/components/"
python3 - "$cfg/fork" <<'PY'
import re, sys
d = sys.argv[1] + "/"
s = open(d + "Service.qml").read()
s = s.replace("PanelWindow {", "FloatingWindow {")
for pat in [r'^\s*screen: modelData\n', r'^\s*WlrLayershell\.[a-zA-Z.]+: .*\n', r'^\s*exclusionMode: .*\n',
            r'^\s*anchors \{ top: true; bottom: true; left: true; right: true \}\n', r'^\s*mask: Region \{ item: popupColumn \}\n']:
    s = re.sub(pat, "", s, flags=re.M)
open(d + "Service.qml", "w").write(s)
m = open(d + "components/SlotMotion.qml").read()
m = m.replace("  property var pendingDone: null",
  "  property var pendingDone: null\n  onPresenceChanged: console.log('PROBE presence=' + presence.toFixed(3))\n"
  "  Component.onCompleted: console.log('PROBE motion created fx=' + fx + ' slowdown=' + slowdown + ' enterMs=' + enterMs)", 1)
open(d + "components/SlotMotion.qml", "w").write(m)
PY

run() { # scenario initial-theme [conf-line]
  local home=$tmp/home-$1-$RANDOM
  mkdir -p "$home/.local/state/omarchy/current" "$home/.config/omarchy"
  printf '%s' "$2" >"$home/.local/state/omarchy/current/theme.name"
  [[ -n ${3:-} ]] && printf '%s\n' "$3" >"$home/.config/omarchy/annihilation-notifications-fork.conf"
  (cd "$cfg" && env -u DISPLAY -u WAYLAND_DISPLAY HOME="$home" XDG_RUNTIME_DIR="$tmp/xdg" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
     PROBE_SCENARIO="$1" timeout 40 quickshell -p shell.qml --no-duplicate 2>&1) | sed 's/\x1b\[[0-9;]*m//g' | grep "PROBE" | sed 's/^.*PROBE /PROBE /'
}
mkdir -p "$tmp/xdg"; chmod 700 "$tmp/xdg"

# -- the setting parser
out=$(run plain annihilation)
parsed() { sed -n "s/^PROBE parse $1 -> //p" <<<"$out"; }
check "parse: no setting is 1" 1 "$(parsed empty)"
check "parse: plain" 2 "$(parsed plain)"
check "parse: spaces around = and the value are fine" 4 "$(parsed spaced)"
check "parse: decimals" 0.5 "$(parsed decimal)"
check "parse: below 0.25 is ignored" 1 "$(parsed 'too small')"
check "parse: above 8 is ignored" 1 "$(parsed 'too big')"
check "parse: junk is ignored" 1 "$(parsed junk)"
check "parse: found among other keys" 3 "$(parsed 'other keys')"
check "parse: a different key only" 1 "$(parsed 'no key')"
check "parse: trailing junk is ignored" 1 "$(parsed 'trailing junk')"

# -- another theme: stock behaviour, nothing animates
out=$(run plain other)
has "other theme: the toast was inserted with the gate closed" "PROBE insert 1 themed=false" "$out"
has "other theme: the slot is created with fx=false" "motion created fx=false" "$out"
check "other theme: presence never moves" 0 "$(grep -c 'PROBE presence=' <<<"$out")"

# -- the annihilation theme: it animates, from 0 up to 1
out=$(run themed annihilation)
has "annihilation: the gate is open when the toast arrives" "PROBE insert 1 themed=true" "$out"
has "annihilation: the slot is created with fx=true" "motion created fx=true slowdown=1 enterMs=480" "$out"
first=$(grep -m1 'PROBE presence=' <<<"$out" | sed 's/.*=//'); last=$(grep 'PROBE presence=' <<<"$out" | tail -n1 | sed 's/.*=//')
check "annihilation: presence starts at 0" 0.000 "$first"
check "annihilation: and ends at 1" 1.000 "$last"
n=$(grep -c 'PROBE presence=' <<<"$out"); (( n > 12 )) && n=many
check "annihilation: it takes many frames, not one jump" many "$n"
mono=$(grep 'PROBE presence=' <<<"$out" | sed 's/.*=//' | awk 'NR>1 && $1 < prev {bad=1} {prev=$1} END{print bad ? "no" : "yes"}')
check "annihilation: and only ever rises" yes "$mono"

# -- slowdown from the file
out=$(run themed annihilation "motion_slowdown=3")
has "slowdown 3: the slot sees it" "slowdown=3 enterMs=1440" "$out"
fast=$(run themed annihilation | grep -c 'PROBE presence='); slow=$(grep -c 'PROBE presence=' <<<"$out")
check "slowdown 3: the entry has more frames than the designed one" yes "$([[ $slow -gt $fast ]] && echo yes || echo no)"

# -- switching theme live, without a restart
out=$(run switch other)
has "live switch: the gate starts closed on another theme" "PROBE early themed=false" "$out"
has "live switch: after the theme file changes it opens, with no restart" "PROBE insert 1 themed=true" "$out"
has "live switch: and the toast then animates" "motion created fx=true" "$out"
has "live switch: back to another theme, toast 2 is stock" "PROBE insert 2 themed=false" "$out"
check "live switch: exactly one slot animated (fx=true) and one did not" "1 1" "$(grep -c 'created fx=true' <<<"$out") $(grep -c 'created fx=false' <<<"$out")"

echo
if (( fail == 0 )); then echo "ALL $pass CHECKS PASS"; else echo "$fail FAILED, $pass passed"; fi
exit $(( fail ? 1 : 0 ))
