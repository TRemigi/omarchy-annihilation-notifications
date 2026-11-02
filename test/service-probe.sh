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
cp "$HERE/Service.qml" "$HERE/NotificationLogic.js" "$HERE/ArrivalLogic.js" "$cfg/fork/"; cp "$HERE"/components/*.qml "$cfg/fork/components/"
cp -r "$HERE/fonts" "$cfg/fork/fonts"                       # the card loads Jost and Cinzel from ../fonts
python3 - "$cfg/fork" <<'PY'
import re, sys
d = sys.argv[1] + "/"
s = open(d + "Service.qml").read()
s = s.replace("PanelWindow {", "FloatingWindow {")
# a toast that clicks itself 300 ms after it appears, when PROBE_CLICK is set (a click removes it at once, with no fold)
s = s.replace("            Component.onCompleted: motion.enter()\n", "            Component.onCompleted: { motion.enter(); if (Quickshell.env('PROBE_CLICK') === '1') clicker.start() }\n            Timer { id: clicker; interval: 300; onTriggered: card.cardClicked() }\n", 1)
# a log of the window, which has to outlive its toasts
s = s.replace("FloatingWindow {\n", "FloatingWindow {\n      Timer { interval: 400; running: true; repeat: true; onTriggered: console.log('PROBE win rows=' + popupModel.count + ' visible=' + visible + ' spores=' + sporeLayer.active + ' arrival=' + arrivalLayer.active) }\n", 1)
for pat in [r'^\s*screen: modelData\n', r'^\s*WlrLayershell\.[a-zA-Z.]+: .*\n', r'^\s*exclusionMode: .*\n',
            r'^\s*anchors \{ top: true; bottom: true; left: true; right: true \}\n', r'^\s*mask: Region \{ item: popupColumn \}\n']:
    s = re.sub(pat, "", s, flags=re.M)
open(d + "Service.qml", "w").write(s)
m = open(d + "components/SlotMotion.qml").read()
m = m.replace("  property var pendingDone: null",
  "  property var pendingDone: null\n  onPresenceChanged: console.log('PROBE presence=' + presence.toFixed(3))\n  Connections { target: root; function onDissolveChanged() { console.log('PROBE dissolve=' + root.dissolve.toFixed(3)) } }\n"
  "  Component.onCompleted: console.log('PROBE motion created fx=' + fx + ' slowdown=' + slowdown + ' enterMs=' + enterMs)", 1)
open(d + "components/SlotMotion.qml", "w").write(m)
r = open(d + "components/ToastRim.qml").read()
r = r.replace("  property real energy: 1\n", "  property real energy: 1\n  Timer { interval: 900; running: true; onTriggered: console.log('PROBE rim ' + root.target.summary + ' remaining=' + root.remaining.toFixed(3) + ' urgency=' + root.urgency + ' spores=' + root.spores + ' look=' + root.look + ' visible=' + root.visible + ' gate=' + root.gate.toFixed(2) + ' calm=' + root.calm + ' opacity=' + root.opacity.toFixed(2)) }\n", 1)
open(d + "components/ToastRim.qml", "w").write(r)
sp = open(d + "components/SporeLayer.qml").read()
sp = sp.replace("    if (!(amount > 0)) return\n", "    if (!(amount > 0)) return\n    console.log('PROBE burst urgency=' + urgency + ' size=' + Math.round(w) + 'x' + Math.round(h) + ' amount=' + amount)\n", 1)
open(d + "components/SporeLayer.qml", "w").write(sp)
a = open(d + "components/ArrivalFlare.qml").read()
for ms, tag in ((150, "early"), (2300, "late")):
    a = a.replace("  readonly property real margin: 40\n", "  readonly property real margin: 40\n  Timer { interval: " + str(ms) + "; running: true; onTriggered: console.log('PROBE arrival " + tag + " ' + root.target.summary + ' armed=' + root.armed"
        " + ' revealing=' + root.revealing + ' p=' + root.p.toFixed(2) + ' front=' + root.front.toFixed(0) + ' gate=' + root.rimGate.toFixed(2) + ' opacity=' + root.target.opacity.toFixed(2)"
        " + ' scale=' + root.target.scale.toFixed(2) + ' layer=' + root.target.layer.enabled + ' reach=' + root.cardReach.toFixed(0) + ' visible=' + root.visible) }\n", 1)
a = a.replace("  readonly property real margin: 40\n", "  readonly property real margin: 40\n  Timer { interval: 100; running: root.exiting; repeat: true; onTriggered: console.log('PROBE exitstate q=' + root.q.toFixed(2) + ' front=' + root.front.toFixed(0) + ' gate=' + root.rimGate.toFixed(2)"
    " + ' revealing=' + root.revealing + ' layer=' + root.target.layer.enabled + ' visible=' + root.visible + ' fade=' + root.fade.toFixed(2) + ' reach=' + root.cardReach.toFixed(0) + ' opacity=' + root.target.opacity.toFixed(2)) }\n", 1)
open(d + "components/ArrivalFlare.qml", "w").write(a)
al = open(d + "components/ArrivalLayer.qml").read()
al = al.replace("  enabled: false                      // click-through\n", "  enabled: false                      // click-through\n  Timer { interval: 1500; running: true; onTriggered: console.log('PROBE layer events=' + root.events.length + ' active=' + root.active + ' strength=' + root.strength"
    " + ' exits=' + root.events.filter(function(e) { return e.exit }).length + ' fills=' + (root.parent !== null && root.width === root.parent.width && root.height === root.parent.height && root.width > 0) + ' amps=' + root.events.map(function(e) { return e.amp.toFixed(2) }).join(',') + ' reach=' + root.ringReach.toFixed(0) + ' first=' + (root.events.length ? root.events[0].w + 'x' + root.events[0].h + '@' + Math.round(root.events[0].x) + ',' + Math.round(root.events[0].y) + ' urg=' + root.events[0].urgency + ' amp=' + root.events[0].amp.toFixed(2) + ' dur=' + root.events[0].dur : 'none')) }\n", 1)
al = al.replace("  enabled: false                      // click-through\n", "  enabled: false                      // click-through\n  Timer { interval: 3000; running: Quickshell.env('PROBE_SCENARIO') === 'cards'; onTriggered: { root.events = [{ exit: true, p0: 0.4, start: 100, dur: 1000, item: null, x: 0, y: 0, w: 1, h: 1, ix: 0, iy: 0, cardReach: 1, urgency: 1, amp: 1, salt: 0 }]; console.log('PROBE exitp=' + root.progressAt(0, 600).toFixed(3)) } }\n", 1)
al = al.replace("import QtQuick\n", "import QtQuick\nimport Quickshell\n", 1)
open(d + "components/ArrivalLayer.qml", "w").write(al)
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
s = re.sub(r'^\s*ArrivalFlare \{\n.*?^\s*\}\n', '', s, flags=re.M | re.S)
s = re.sub(r'^\s*ArrivalLayer \{\n.*?^\s*\}\n', '', s, flags=re.M | re.S)
s = re.sub(r'^\s*layer\.enabled: arrival\.revealing\n\s*layer\.effect: ShaderEffect \{\n.*?^\s*\}\n', '', s, flags=re.M | re.S)
s = re.sub(r'^\s*gate: arrival\.rimGate.*\n', '', s, flags=re.M)
s = re.sub(r'^\s*calm: arrival\.armed.*\n', '', s, flags=re.M)
s = s.replace(" || arrivalLayer.active", "")
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
     PROBE_SCENARIO="$1" timeout 40 quickshell -p shell.qml --no-duplicate 2>&1) | tee -a "${PROBE_RAW:-/dev/null}" | sed 's/\x1b\[[0-9;]*m//g' | grep "PROBE" | sed 's/^.*PROBE /PROBE /'
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
check "parse: the last line for a key wins (echo key=value >> file overrides)" 4 "$(parsed 'later line wins')"
check "parse: a later junk line does not cancel an earlier good one" 2 "$(parsed 'a later junk line does not cancel')"
check "parse: a later out-of-range value is ignored, not the default (the whole key falls back)" 1 "$(parsed 'a later out-of-range line is used and ignored')"

parseds() { sed -n "s/^PROBE parseS $1 -> //p" <<<"$out"; }
check "spore_amount: the default is 1" 1 "$(parseds empty)"
check "spore_amount: plain" 0.3 "$(parseds plain)"
check "spore_amount: 0 is allowed" 0 "$(parseds zero)"
check "spore_amount: above 1 is ignored" 1 "$(parseds above)"
check "spore_amount: junk is ignored" 1 "$(parseds junk)"
parsedl() { sed -n "s/^PROBE parseL $1 -> //p" <<<"$out"; }
check "look: the default is blend" blend "$(parsedl empty)"
check "look: growth" growth "$(parsedl growth)"
check "look: the last line wins (blend then growth is growth)" growth "$(parsedl 'later line wins')"
check "look: the last line wins (growth then blend is blend)" blend "$(parsedl 'later line wins back')"
check "look: a later unknown name wins too, and means blend" blend "$(parsedl 'later unknown')"
check "look: glow is gone (an old conf line means blend)" blend "$(parsedl glow)"
parseda() { sed -n "s/^PROBE parseA $1 -> //p" <<<"$out"; }
check "arrival: the default is 1" 1 "$(parseda empty)"
check "arrival: plain" 0.5 "$(parseda plain)"
check "arrival: 0 turns it off and is allowed" 0 "$(parseda zero)"
check "arrival: 2 is the most" 2 "$(parseda two)"
check "arrival: above 2 is ignored" 1 "$(parseda above)"
check "arrival: junk is ignored" 1 "$(parseda junk)"
check "arrival: the last line wins" 1.5 "$(parseda 'later line wins')"
check "look: blend" blend "$(parsedl blend)"
check "look: spaces around = are fine" growth "$(parsedl spaced)"
check "look: an unknown name falls back to blend" blend "$(parsedl unknown)"
check "look: found beside another key" growth "$(parsedl 'beside others')"
check "look: a value that merely starts with growth is not growth" blend "$(parsedl 'prefix only')"
check "look: a key that merely ends in look is not look" blend "$(parsedl 'other key')"
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
has "annihilation: the slot is created with fx=true" "motion created fx=true slowdown=1 enterMs=300" "$out"
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

# -- the faint spores off the card follow spore_amount
check "ambient spores: on by default (the rim gets spores=1)" 1 "$(rimval "$(rimline 'from signal')" spores)"
out_half=$(run cards annihilation "spore_amount=0.5")
check "ambient spores: spore_amount=0.5 reaches the rim" 0.5 "$(rimval "$(grep 'PROBE rim from signal ' <<<"$out_half" | head -n1)" spores)"
check "look: the rim is the blend by default" blend "$(rimval "$(rimline 'from signal')" look)"
out_growth=$(run cards annihilation "look=growth")
check "look: look=growth reaches the rim" growth "$(rimval "$(grep 'PROBE rim from signal ' <<<"$out_growth" | head -n1)" look)"
# -- the arrival: a front of light out of the icon, the card revealed by it, the ring under the cards, the rim handed over
arrline() { grep "PROBE arrival $1 $2 " <<<"$3" | head -n1; }
av() { sed -n "s/.* $2=\([^ ]*\).*/\1/p" <<<"$1"; }
out_arr=$out_cards
e=$(arrline early 'from signal' "$out_arr"); l=$(arrline late 'from signal' "$out_arr")
check "arrival: a fresh toast is armed and under way early on" "true true" "$(av "$e" armed) $(av "$e" revealing)"
check "arrival: the card is a mask layer while the front crosses it" true "$(av "$e" layer)"
check "arrival: the front has left the icon but not crossed the card" yes "$(awk -v f="$(av "$e" front)" -v r="$(av "$e" reach)" 'BEGIN{print (f > 5 && f < r) ? "yes" : "no"}')"
check "arrival: the card is not faded or scaled in (the front reveals it)" "1.00 1.00" "$(av "$e" opacity) $(av "$e" scale)"
check "arrival: the settled rim waits for the front (gate 0 early on)" "0.00" "$(av "$e" gate)"
check "arrival: the edge flare is drawn while the front crosses" true "$(av "$e" visible)"
check "arrival: about two seconds in, it is over: not armed, no mask, the rim is fully in" "false false 1.00" "$(av "$l" armed) $(av "$l" layer) $(av "$l" gate)"
check "arrival: and the flare is gone" false "$(av "$l" visible)"
check "arrival: every toast arrives, not only the first" 5 "$(grep -c 'PROBE arrival early from' <<<"$out_arr")"
ly=$(grep 'PROBE layer ' <<<"$out_arr" | head -n1)
check "arrival: the ring layer is told (three at once at most)" "3 true" "$(av "$ly" events) $(av "$ly" active)"
check "exit: the ring's progress for an exit event runs backwards (halfway through the dissolve, from a start of 0.4, it is at 0.2)" "exitp=0.200" "$(grep -m1 'PROBE exitp=' <<<"$out_cards" | sed 's/^PROBE //')"
check "arrival: at full strength" "strength=1" "strength=$(av "$ly" strength)"
check "arrival: the ring layer covers the whole window (a layer sized to the card cut the ring off in a straight line)" "true" "$(av "$ly" fills)"
check "arrival: a burst is thinned and urgency scales it (the last three of five toasts at once: normal 1 x 0.6, critical 1.3 x 0.6, low 0.6 x 0.6)" "amps=0.60,0.78,0.36" "amps=$(av "$ly" amps)"
check "arrival: the ring's reach follows the screen (between 180 and 340)" yes "$(awk -v r="$(av "$ly" reach)" 'BEGIN{print (r >= 180 && r <= 340) ? "yes" : "no"}')"
check "arrival: the ring has the card's own rectangle (a width and a height, read from the card)" yes "$([[ $(av "$ly" first) =~ ^[0-9]+x[0-9]+@ ]] && echo yes || echo no)"
check "arrival: the first toast's duration is a normal one's, 4200 ms" "dur=4200" "dur=$(av "$ly" dur)"
check "arrival: the rim does not also ignite (calm) while the arrival runs" true "$(rimval "$(grep 'PROBE rim from signal ' <<<"$out_arr" | head -n1)" calm)"
out_arr0=$(run cards annihilation "arrival=0")
e0=$(arrline early 'from signal' "$out_arr0")
check "arrival=0: nothing is armed and no mask" "false false" "$(av "$e0" armed) $(av "$e0" layer)"
check "arrival=0: the plain unfold is back (the card is still fading in early)" yes "$(awk -v o="$(av "$e0" opacity)" 'BEGIN{print (o < 1) ? "yes" : "no"}')"
check "arrival=0: the rim is not gated" "1.00" "$(av "$e0" gate)"
check "arrival=0: the ring layer has nothing" "events=0" "events=$(av "$(grep 'PROBE layer ' <<<"$out_arr0" | head -n1)" events)"
check "arrival=0: the rim ignites as it did" false "$(rimval "$(grep 'PROBE rim from signal ' <<<"$out_arr0" | head -n1)" calm)"
out_arr_half=$(run cards annihilation "arrival=0.5")
check "arrival=0.5 reaches the layer" "strength=0.5" "strength=$(av "$(grep 'PROBE layer ' <<<"$out_arr_half" | head -n1)" strength)"
out_arr_other=$(run cards other)
check "another theme: no arrival (stock)" "false false" "$(av "$(arrline early 'from signal' "$out_arr_other")" armed) $(av "$(arrline early 'from signal' "$out_arr_other")" layer)"
out_stale=$(run stale annihilation)
check "a toast that is a minute old (restored after a restart) does not arrive" "false" "$(av "$(arrline early 'old toast' "$out_stale")" armed)"
check "and a fresh one beside it does" "true" "$(av "$(arrline early 'new toast' "$out_stale")" armed)"
out_crit=$(run crit annihilation)
check "a critical toast's arrival lasts 6000 ms" "dur=6000" "dur=$(av "$(grep 'PROBE layer ' <<<"$out_crit" | head -n1)" dur)"
out_slow=$(run cards annihilation "motion_slowdown=2")
check "motion_slowdown=2 doubles the arrival too" "dur=8400" "dur=$(av "$(grep 'PROBE layer ' <<<"$out_slow" | head -n1)" dur)"
check "arrival: the settled rim's own gate is closed while the front crosses (slowed, so at 0.9 s it has barely started)" "0.00" "$(rimval "$(grep 'PROBE rim from signal ' <<<"$out_slow" | head -n1)" gate)"
check "arrival=0: and the rim's gate is open" "1.00" "$(rimval "$(grep 'PROBE rim from signal ' <<<"$out_arr0" | head -n1)" gate)"
check "arrival: the rim is not drawn while gated (its own opacity is 0 early in a slowed arrival)" "0.00" "$(rimval "$(grep 'PROBE rim from signal ' <<<"$out_slow" | head -n1)" opacity)"
check "arrival=0: and it is drawn (opacity 1)" "1.00" "$(rimval "$(grep 'PROBE rim from signal ' <<<"$out_arr0" | head -n1)" opacity)"
out_none=$(run cards annihilation "spore_amount=0")
check "ambient spores: spore_amount=0 turns them off" 0 "$(rimval "$(grep 'PROBE rim from signal ' <<<"$out_none" | head -n1)" spores)"

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
check "arrival: the window stays up for the ring after the toast and its spores are gone" yes "$([[ -n $(grep 'PROBE win rows=0 visible=true spores=false arrival=true' <<<"$out") ]] && echo yes || echo no)"
check "arrival: the window was never hidden while the ring was active" 0 "$(grep -c 'PROBE win rows=0 visible=false .*arrival=true' <<<"$out")"
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

# -- the exit: the arrival played backwards (the same scenario: toasts last 0.7 s, so one leaves by itself)
out=$(run spores annihilation)
dis=$(grep -c 'PROBE dissolve=' <<<"$out"); (( dis > 12 )) && dis=many
check "exit: the card dissolves over many frames, not one jump" many "$dis"
check "exit: the dissolve runs from the start to 1" "yes 1.000" "$(awk -v d="$(grep -m1 'PROBE dissolve=' <<<"$out" | sed 's/.*=//')" 'BEGIN{print (d < 0.1) ? "yes" : "no"}') $(grep 'PROBE dissolve=' <<<"$out" | tail -n1 | sed 's/.*=//')"
check "exit: and only ever rises" yes "$(grep 'PROBE dissolve=' <<<"$out" | sed 's/.*=//' | awk 'NR>1 && $1 < prev {bad=1} {prev=$1} END{print bad ? "no" : "yes"}')"
# the slot starts to fold (presence falls below 1 after the entry) only once the dissolve is mostly done: the last dissolve value before the first fall
fold=$(awk '/PROBE dissolve=/ {d=$NF; sub(/.*=/,"",d)} /PROBE presence=/ {v=$NF; sub(/.*=/,"",v); if (d != "" && v < 1) {print d; exit}}' <<<"$out")
check "exit: the slot folds shut only once the dissolve is mostly done (not before 0.8)" yes "$(awk -v d="$fold" 'BEGIN{print (d != "" && d >= 0.79 && d <= 0.9) ? "yes" : "no"}')"
check "exit: the toast's row still goes in the end, and the window with it" yes "$([[ -n $(grep 'PROBE win rows=0 visible=false' <<<"$out") ]] && echo yes || echo no)"
# the spores are released a quarter of the way into the dissolve, when the card starts to come apart
burstat=$(awk '/PROBE dissolve=/ {d=$NF; sub(/.*=/,"",d)} /PROBE burst/ {print d; exit}' <<<"$out")
check "exit: the spores are released a quarter of the way into the dissolve, not at the very start" yes "$(awk -v d="$burstat" 'BEGIN{print (d != "" && d >= 0.2 && d <= 0.4) ? "yes" : "no"}')"
check "exit: the ring is told, to contract onto the card" "exits=1" "exits=$(av "$(grep 'PROBE layer ' <<<"$out" | head -n1)" exits)"
ex_first=$(grep -m1 'PROBE exitstate' <<<"$out"); ex_last=$(grep 'PROBE exitstate' <<<"$out" | tail -n1)
check "exit: it starts early in the dissolve, with the settled rim still lit (its gate falling from 1)" yes "$(awk -v q="$(av "$ex_first" q)" -v g="$(av "$ex_first" gate)" 'BEGIN{print (q <= 0.2 && g > 0.3) ? "yes" : "no"}')"
check "exit: the front retreats (only ever falls)" yes "$(grep 'PROBE exitstate' <<<"$out" | sed 's/.* front=\([-0-9]*\) .*/\1/' | awk 'NR>1 && $1 > prev {bad=1} {prev=$1} END{print bad ? "no" : "yes"}')"
check "exit: the card is a mask layer while the front crosses it" true "$(grep 'PROBE exitstate' <<<"$out" | grep -c 'layer=true' | awk '{print ($1 > 0) ? "true" : "false"}')"
check "exit: the settled rim fades out (its gate falls to 0)" "0.00" "$(av "$ex_last" gate)"
check "exit: and the card is not faded or scaled (the front takes it away)" "1.00" "$(grep 'PROBE exitstate' <<<"$out" | sed -n 's/.* opacity=\([0-9.]*\).*/\1/p' | sort -u | tr '\n' ' ' | sed 's/ $//')"
out_x0=$(run spores annihilation "arrival=0")
check "exit: with arrival=0 there is no dissolve (the old fold, 300 ms)" 0 "$(grep -c 'PROBE dissolve=' <<<"$out_x0")"
check "exit: and the spores are released at once, as before (one burst)" 1 "$(grep -c 'PROBE burst' <<<"$out_x0")"
out_xc=$(PROBE_CLICK=1 run spores annihilation)
check "exit: a click is instant, no dissolve" 0 "$(grep -c 'PROBE dissolve=' <<<"$out_xc")"
out_xo=$(run spores other)
check "exit: another theme is stock, no dissolve" 0 "$(grep -c 'PROBE dissolve=' <<<"$out_xo")"
out_xs=$(run spores annihilation "motion_slowdown=2")
check "exit: motion_slowdown=2 doubles it (the dissolve takes twice as many frames' time: the last frame is as late)" yes "$([[ $(grep -c 'PROBE dissolve=' <<<"$out_xs") -ge $(grep -c 'PROBE dissolve=' <<<"$out") ]] && echo yes || echo no)"

CFGDIR=$cfg     # back to the normal lifetimes for the rest

# -- slowdown from the file
out=$(run themed annihilation "motion_slowdown=3")
has "slowdown 3: the slot sees it" "slowdown=3 enterMs=900" "$out"
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
