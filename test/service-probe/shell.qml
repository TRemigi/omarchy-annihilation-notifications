// Drives the REAL Service.qml inside an offscreen Quickshell (see ../service-probe.sh, which patches the
// layer-shell window for a plain one) and prints PROBE lines for the shell script to check.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "fork"

ShellRoot {
  id: root
  property string scenario: Quickshell.env("PROBE_SCENARIO")
  property string themeFile: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
  property int nextId: 1

  Service { id: svc; shell: null }

  function setTheme(name) { Quickshell.execDetached(["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "--", name, themeFile]) }
  function addToast(app, glyph, summary, urgency, ageMs) {
    var id = nextId++
    console.log("PROBE insert " + id + " themed=" + svc.themed + " slowdown=" + svc.motionSlowdown)
    svc.popupModel.insert(0, { id: id, originalId: id, app: app || "Signal", appIcon: "", summary: summary || ("probe " + id), body: "body", image: "", glyph: glyph || "", execArgv: "", urgency: urgency === undefined ? 1 : urgency, expireTimeout: 0, timestamp: Date.now() - (ageMs || 0) })
  }
  function parse(label, raw) { console.log("PROBE parse " + label + " -> " + svc.parseSlowdown(raw)) }
  function parseS(label, raw) { console.log("PROBE parseS " + label + " -> " + svc.parseSpores(raw)) }
  function parseL(label, raw) { console.log("PROBE parseL " + label + " -> " + svc.parseLook(raw)) }
  function parseA(label, raw) { console.log("PROBE parseA " + label + " -> " + svc.parseArrival(raw)) }
  function parseP(label, raw) { console.log("PROBE parseP " + label + " -> " + svc.parsePosition(raw)) }
  function parseV(label, raw) { console.log("PROBE parseV " + label + " -> " + svc.parseVividness(raw)) }

  Component.onCompleted: {
    parse("empty", ""); parse("plain", "motion_slowdown=2"); parse("spaced", "  motion_slowdown = 4  ")
    parse("decimal", "motion_slowdown=0.5"); parse("too small", "motion_slowdown=0.1"); parse("too big", "motion_slowdown=99")
    parse("junk", "motion_slowdown=abc"); parse("other keys", "x=1\nmotion_slowdown=3\ny=2\n"); parse("no key", "x=1")
    parse("trailing junk", "motion_slowdown=3x"); parse("later line wins", "motion_slowdown=2\nmotion_slowdown=4\n"); parse("a later junk line does not cancel", "motion_slowdown=2\nmotion_slowdown=abc\n"); parse("a later out-of-range line is used and ignored", "motion_slowdown=2\nmotion_slowdown=99\n")
    parseV("empty", ""); parseV("plain", "rim_vividness=0.4"); parseV("zero is allowed", "rim_vividness=0"); parseV("one is allowed", "rim_vividness=1")
    parseV("above 1", "rim_vividness=1.5"); parseV("junk", "rim_vividness=loud"); parseV("beside the other key", "motion_slowdown=2\nrim_vividness=0.9\n")
    parseV("the other key only", "motion_slowdown=2")
    parseL("empty", ""); parseL("growth", "look=growth"); parseL("blend", "look=blend"); parseL("spaced", "  look = growth  "); parseL("unknown", "look=neon")
    parseL("beside others", "motion_slowdown=2\nlook=growth\n"); parseL("prefix only", "look=growthy"); parseL("glow", "look=glow"); parseL("later line wins", "look=blend\nlook=growth\n"); parseL("later line wins back", "look=growth\nlook=blend\n"); parseL("later unknown", "look=growth\nlook=neon\n"); parseL("glow prefix", "look=glowing"); parseL("other key", "xlook=growth")
    parseA("empty", ""); parseA("plain", "arrival=0.5"); parseA("zero", "arrival=0"); parseA("two", "arrival=2"); parseA("above", "arrival=3"); parseA("junk", "arrival=big"); parseA("later line wins", "arrival=0.5\narrival=1.5\n")
    parseP("empty", ""); parseP("center", "position=center"); parseP("right", "position=right"); parseP("spaced", "  position = center  "); parseP("unknown", "position=left"); parseP("later wins", "position=center\nposition=right\n"); parseP("later wins back", "position=right\nposition=center\n"); parseP("prefix", "position=centered"); parseP("beside others", "arrival=1\nposition=center\n")
    parseS("empty", ""); parseS("plain", "spore_amount=0.3"); parseS("zero", "spore_amount=0"); parseS("above", "spore_amount=2"); parseS("junk", "spore_amount=lots")
  }

  Timer { interval: 400; running: true; onTriggered: console.log("PROBE early themed=" + svc.themed) }
  Timer { interval: 900; running: true; onTriggered: {
    if (scenario === "stale") { addToast("Signal", "", "old toast", 1, 60000); addToast("Signal", "", "new toast") }
    if (scenario === "crit") { addToast("Power", "", "from power", 2) }
    if (scenario === "cards") { addToast("Signal", "", "from signal"); addToast("omarchy-action", "G", "from omarchy"); addToast("notify-send", "", "from notify-send"); addToast("Power", "", "from power", 2); addToast("Mail", "", "from mail", 0) }
  } }
  Timer { interval: 700; running: true; onTriggered: {
    if (scenario === "switch") { setTheme("annihilation") }
    if (scenario === "plain") { addToast() }
  } }
  Timer { interval: 1500; running: true; onTriggered: {
    if (scenario === "switch") { addToast(); }
    if (scenario === "themed") { addToast() }
  } }
  Timer { interval: 2600; running: true; onTriggered: { if (scenario === "switch") setTheme("other") } }
  Timer { interval: 3400; running: true; onTriggered: { if (scenario === "switch") addToast() } }
  Timer { interval: 600; running: true; onTriggered: { if (scenario === "spores") addToast("Signal", "", "dissolve") } }
  Timer { interval: scenario === "spores" ? 6800 : 4600; running: true; onTriggered: Qt.quit() }
}
