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
cp -r "$HERE/fonts" "$cfg/fork/fonts"                       # the card loads Jost and Cinzel from ../fonts
python3 - "$cfg/fork" <<'PY'
import re, sys
d = sys.argv[1] + "/"
s = open(d + "Service.qml").read()
s = s.replace("PanelWindow {", "FloatingWindow {")
# a toast that clicks itself 300 ms after it appears, when PROBE_CLICK is set (a click removes it at once, with no fold)
s = s.replace("            Component.onCompleted: motion.enter()\n", "            Component.onCompleted: { motion.enter(); if (Quickshell.env('PROBE_CLICK') === '1') clicker.start() }\n            Timer { id: clicker; interval: 300; onTriggered: card.cardClicked() }\n", 1)
# a log of the window, which has to outlive its toasts
s = s.replace("FloatingWindow {\n", "FloatingWindow {\n      Timer { interval: 400; running: true; repeat: true; onTriggered: console.log('PROBE win rows=' + popupModel.count + ' visible=' + visible + ' spores=' + sporeLayer.active) }\n", 1)
for pat in [r'^\s*screen: modelData\n', r'^\s*WlrLayershell\.[a-zA-Z.]+: .*\n', r'^\s*exclusionMode: .*\n',
            r'^\s*anchors \{ top: true; bottom: true; left: true; right: true \}\n', r'^\s*mask: Region \{ item: popupColumn \}\n']:
    s = re.sub(pat, "", s, flags=re.M)
open(d + "Service.qml", "w").write(s)
m = open(d + "components/SlotMotion.qml").read()
m = m.replace("  property var pendingDone: null",
  "  property var pendingDone: null\n  onPresenceChanged: console.log('PROBE presence=' + presence.toFixed(3))\n"
  "  Component.onCompleted: console.log('PROBE motion created fx=' + fx + ' slowdown=' + slowdown + ' enterMs=' + enterMs)", 1)
open(d + "components/SlotMotion.qml", "w").write(m)
r = open(d + "components/ToastRim.qml").read()
r = r.replace("  property real energy: 1\n", "  property real energy: 1\n  Timer { interval: 900; running: true; onTriggered: console.log('PROBE rim ' + root.target.summary + ' remaining=' + root.remaining.toFixed(3) + ' urgency=' + root.urgency) }\n", 1)
open(d + "components/ToastRim.qml", "w").write(r)
sp = open(d + "components/SporeLayer.qml").read()
sp = sp.replace("    if (!(amount > 0)) return\n", "    if (!(amount > 0)) return\n    console.log('PROBE burst urgency=' + urgency + ' size=' + Math.round(w) + 'x' + Math.round(h) + ' amount=' + amount)\n", 1)
open(d + "components/SporeLayer.qml", "w").write(sp)
c = open(d + "components/NotificationCard.qml").read()
probe = ("  Timer { interval: 700; running: true; onTriggered: console.log('PROBE card ' + root.summary + ' themed=' + root.themed"
         " + ' family=' + root.textFamily + ' jost=' + jostFont.status + ' cinzel=' + cinzelFont.status + ' caption=' + root.captionText + ' when=' + root.whenText"
         " + ' ring=' + root.iconRing.x.toFixed(0) + ',' + root.iconRing.y.toFixed(0) + ',' + root.iconRing.z.toFixed(0)"
         " + ' size=' + Math.round(root.width) + 'x' + Math.round(root.height) + ' border=' + root.borderTop + ' bordercolor=' + root.cardBorderSpec.color) }\n")
c = c.replace("  property bool themed: false\n", "  property bool themed: false\n" + probe, 1)
open(d + "components/NotificationCard.qml", "w").write(c)
PY

# A second config root whose card is Omarchy's own, pristine from the upstream branch, with only a size probe added:
# what "stock when the theme is off" has to match.
ref=$(git -C "$HERE" rev-parse --verify -q upstream || git -C "$HERE" rev-parse --verify -q origin/upstream || true)
if [[ -n $ref ]]; then
  cfg_stock=$tmp/cfg-stock; cp -a "$cfg" "$cfg_stock"
  git -C "$HERE" show "$ref:components/NotificationCard.qml" >"$cfg_stock/fork/components/NotificationCard.qml"
  # Omarchy's card has no `themed` and no ToastRim, so take the fork's hooks for them out of this copy of the service.
  python3 - "$cfg_stock/fork/Service.qml" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r'^\s*themed: service\.themed\n', '', s, flags=re.M)
s = re.sub(r'^\s*ToastRim \{\n.*?^\s*\}\n', '', s, flags=re.M | re.S)
open(p, "w").write(s)
PY
  python3 - "$cfg_stock/fork/components/NotificationCard.qml" <<'PY'
import sys
p = sys.argv[1]; c = open(p).read()
probe = ("  Timer { interval: 700; running: true; onTriggered: console.log('PROBE card ' + root.summary"
         " + ' size=' + Math.round(root.width) + 'x' + Math.round(root.height)) }\n")
assert "  property int cornerRadius: 0\n" in c
open(p, "w").write(c.replace("  property int cornerRadius: 0\n", "  property int cornerRadius: 0\n" + probe, 1))
PY
fi
# A third config root where toasts last 0.7 s, so that one expires (and dissolves into spores) within a test.
cfg_spores=$tmp/cfg-spores; cp -a "$cfg" "$cfg_spores"
sed -i 's/readonly property int lowPopupDuration: 5000/readonly property int lowPopupDuration: 700/; s/readonly property int normalPopupDuration: 8000/readonly property int normalPopupDuration: 700/' "$cfg_spores/fork/Service.qml"
grep -q 'normalPopupDuration: 700' "$cfg_spores/fork/Service.qml" || { echo "could not shorten the lifetimes for the spore scenarios" >&2; exit 2; }
CFGDIR=$cfg

run() { # scenario initial-theme [conf-line]
  local home=$tmp/home-$1-$RANDOM
  mkdir -p "$home/.local/state/omarchy/current" "$home/.config/omarchy"
  printf '%s' "$2" >"$home/.local/state/omarchy/current/theme.name"
  [[ -n ${3:-} ]] && printf '%s\n' "$3" >"$home/.config/omarchy/annihilation-notifications-fork.conf"
  (cd "$CFGDIR" && env -u DISPLAY -u WAYLAND_DISPLAY HOME="$home" XDG_RUNTIME_DIR="$tmp/xdg" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
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

parseds() { sed -n "s/^PROBE parseS $1 -> //p" <<<"$out"; }
check "spore_amount: the default is 1" 1 "$(parseds empty)"
check "spore_amount: plain" 0.3 "$(parseds plain)"
check "spore_amount: 0 is allowed" 0 "$(parseds zero)"
check "spore_amount: above 1 is ignored" 1 "$(parseds above)"
check "spore_amount: junk is ignored" 1 "$(parseds junk)"
parsedv() { sed -n "s/^PROBE parseV $1 -> //p" <<<"$out"; }
check "vividness: the default is 0.75" 0.75 "$(parsedv empty)"
check "vividness: plain" 0.4 "$(parsedv plain)"
check "vividness: 0 is allowed" 0 "$(parsedv 'zero is allowed')"
check "vividness: 1 is allowed" 1 "$(parsedv 'one is allowed')"
check "vividness: above 1 is ignored" 0.75 "$(parsedv 'above 1')"
check "vividness: junk is ignored" 0.75 "$(parsedv junk)"
check "vividness: found beside the other key" 0.9 "$(parsedv 'beside the other key')"
check "vividness: the other key alone leaves the default" 0.75 "$(parsedv 'the other key only')"

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

# -- the card itself
out=$(run cards annihilation); out_cards=$out
cardline() { grep "PROBE card $1 " <<<"$out" | head -n1; }
field() { sed -n "s/.* $2=\([^ ]*\).*/\1/p" <<<"$1"; }
sig=$(cardline "from signal"); om=$(cardline "from omarchy"); ns=$(cardline "from notify-send")
check "themed card: the gate reaches the card" true "$(field "$sig" themed)"
check "themed card: Jost is loaded and used" "Jost" "$(field "$sig" family)"
check "themed card: both bundled fonts report Ready" "1 1" "$(field "$sig" jost) $(field "$sig" cinzel)"
check "themed card: the caption is the app" Signal "$(field "$sig" caption)"
check "themed card: a fresh toast says now" now "$(field "$sig" when)"
check "themed card: Omarchy's own toasts are captioned Omarchy" Omarchy "$(field "$om" caption)"
check "themed card: a bare notify-send has no caption" "" "$(field "$ns" caption)"
check "themed card: no icon means no ring" "0,0,0" "$(field "$sig" ring)"
check "themed card: Omarchy's own border is made invisible (ToastRim draws the light)" transparent "$(field "$sig" bordercolor)"
ring=$(field "$om" ring); check "themed card: a glyph icon gets a ring 17 px across, on the left, centred on the height" yes "$([[ $ring =~ ^34,[0-9]+,17$ ]] && echo yes || echo no)"
themed_h=$(field "$sig" size | sed 's/.*x//'); themed_b=$(field "$sig" border)
out=$(run cards other)
sig=$(cardline "from signal")
check "other theme: the card is stock (not themed, Omarchy's font)" "false Liberation Sans" "$(field "$sig" themed) $(sed -n 's/.* family=\(.*\) jost=.*/\1/p' <<<"$sig")"
check "other theme: the border keeps its width when themed" "$(field "$sig" border)" "$themed_b"
check "other theme: Omarchy's own border is kept" yes "$([[ -n $(field "$sig" bordercolor) && $(field "$sig" bordercolor) != transparent ]] && echo yes || echo no)"
plain_h=$(field "$sig" size | sed 's/.*x//')
check "the themed card is taller than stock by the caption row, and not by more than a line or two" yes "$([[ $themed_h -gt $plain_h && $((themed_h - plain_h)) -lt 30 ]] && echo yes || echo no)"

# -- the countdown follows the toast's own clock
rimline() { grep "PROBE rim $1 " <<<"$out_cards" | head -n1; }
rimval() { sed -n "s/.* $2=\([^ ]*\).*/\1/p" <<<"$1"; }
sigrem=$(rimval "$(rimline 'from signal')" remaining)
check "countdown: a normal toast has used up a little of its life, but not much, after about a second" yes "$(awk -v v="$sigrem" 'BEGIN{print (v > 0.80 && v < 0.99) ? "yes" : "no"}')"
check "countdown: a critical toast never expires, so it has no countdown" -1.000 "$(rimval "$(rimline 'from power')" remaining)"
check "countdown: a low toast has one" yes "$(awk -v v="$(rimval "$(rimline 'from mail')" remaining)" 'BEGIN{print (v > 0 && v < 1) ? "yes" : "no"}')"
check "countdown: the urgency reaches the shader (critical is 2)" 2 "$(rimval "$(rimline 'from power')" urgency)"
check "countdown: a low toast's life is shorter (5 s, not 8), so it has used up more of it" yes "$(awk -v a="$sigrem" -v b="$(rimval "$(rimline 'from mail')" remaining)" 'BEGIN{print (b < a) ? "yes" : "no"}')"

# -- with the theme off, the card is exactly Omarchy's: the same size as the pristine upstream card, for every kind of toast
if [[ -n $ref ]]; then
  fork_sizes=$(for k in "from signal" "from omarchy" "from notify-send"; do field "$(grep "PROBE card $k " <<<"$out" | head -n1)" size; done | tr '\n' ' ')
  CFGDIR=$cfg_stock; out_stock=$(run cards other); CFGDIR=$cfg
  stock_sizes=$(for k in "from signal" "from omarchy" "from notify-send"; do field "$(grep "PROBE card $k " <<<"$out_stock" | head -n1)" size; done | tr '\n' ' ')
  check "theme off: every card is the same size as Omarchy's pristine card" "$stock_sizes" "$fork_sizes"
  check "theme off: and those sizes were actually read" 3 "$(wc -w <<<"$stock_sizes" | tr -d ' ')"
else
  echo "note: no upstream branch here, so the pristine-card comparison was skipped"
fi

# -- spores: a toast that leaves dissolves into them, from a layer that outlives it
CFGDIR=$cfg_spores
out=$(run spores annihilation)
check "spores: a toast that expires releases exactly one burst" 1 "$(grep -c 'PROBE burst' <<<"$out")"
b=$(grep -m1 'PROBE burst' <<<"$out")
check "spores: it is a normal toast's burst, from a card of some size, at full amount" yes "$([[ $b == *'urgency=1'* && $b =~ size=[1-9][0-9]+x[1-9][0-9]+ && $b == *'amount=1'* ]] && echo yes || echo no)"
check "spores: the window stays up after the toast is gone, while the spores drift" yes "$([[ -n $(grep 'PROBE win rows=0 visible=true spores=true' <<<"$out") ]] && echo yes || echo no)"
check "spores: and goes away once they have faded" yes "$([[ -n $(grep 'PROBE win rows=0 visible=false spores=false' <<<"$out") ]] && echo yes || echo no)"
check "spores: the window was never hidden while spores were active" 0 "$(grep -c 'PROBE win rows=0 visible=false spores=true' <<<"$out")"
out=$(PROBE_CLICK=1 run spores annihilation)
check "spores: a toast that is clicked dissolves too, exactly once" 1 "$(grep -c 'PROBE burst' <<<"$out")"
check "spores: and its row goes at once, with the window kept up for the spores" yes "$([[ -n $(grep 'PROBE win rows=0 visible=true spores=true' <<<"$out") ]] && echo yes || echo no)"
out=$(PROBE_CLICK=1 run spores other)
check "spores: a click on another theme releases none (stock)" 0 "$(grep -c 'PROBE burst' <<<"$out")"
out=$(run spores other)
check "spores: with another theme there are none" 0 "$(grep -c 'PROBE burst' <<<"$out")"
check "spores: and the window goes away with the toast, as stock (never visible with no rows)" 0 "$(grep -c 'PROBE win rows=0 visible=true' <<<"$out")"
out=$(run spores annihilation "spore_amount=0")
check "spores: spore_amount=0 releases none" 0 "$(grep -c 'PROBE burst' <<<"$out")"
check "spores: and the toast still goes, and the window with it" yes "$([[ -n $(grep 'PROBE win rows=0 visible=false' <<<"$out") ]] && echo yes || echo no)"
out=$(run spores annihilation "spore_amount=0.5")
check "spores: spore_amount=0.5 reaches the layer" yes "$([[ $(grep -m1 'PROBE burst' <<<"$out") == *'amount=0.5'* ]] && echo yes || echo no)"

CFGDIR=$cfg     # back to the normal lifetimes for the rest

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
