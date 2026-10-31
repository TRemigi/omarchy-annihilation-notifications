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
  function addToast(app, glyph, summary, urgency) {
    var id = nextId++
    console.log("PROBE insert " + id + " themed=" + svc.themed + " slowdown=" + svc.motionSlowdown)
    svc.popupModel.insert(0, { id: id, originalId: id, app: app || "Signal", appIcon: "", summary: summary || ("probe " + id), body: "body", image: "", glyph: glyph || "", execArgv: "", urgency: urgency === undefined ? 1 : urgency, expireTimeout: 0, timestamp: Date.now() })
  }
  function parse(label, raw) { console.log("PROBE parse " + label + " -> " + svc.parseSlowdown(raw)) }
  function parseV(label, raw) { console.log("PROBE parseV " + label + " -> " + svc.parseVividness(raw)) }

  Component.onCompleted: {
    parse("empty", ""); parse("plain", "motion_slowdown=2"); parse("spaced", "  motion_slowdown = 4  ")
    parse("decimal", "motion_slowdown=0.5"); parse("too small", "motion_slowdown=0.1"); parse("too big", "motion_slowdown=99")
    parse("junk", "motion_slowdown=abc"); parse("other keys", "x=1\nmotion_slowdown=3\ny=2\n"); parse("no key", "x=1")
    parse("trailing junk", "motion_slowdown=3x")
    parseV("empty", ""); parseV("plain", "rim_vividness=0.4"); parseV("zero is allowed", "rim_vividness=0"); parseV("one is allowed", "rim_vividness=1")
    parseV("above 1", "rim_vividness=1.5"); parseV("junk", "rim_vividness=loud"); parseV("beside the other key", "motion_slowdown=2\nrim_vividness=0.9\n")
    parseV("the other key only", "motion_slowdown=2")
  }

  Timer { interval: 400; running: true; onTriggered: console.log("PROBE early themed=" + svc.themed) }
  Timer { interval: 900; running: true; onTriggered: {
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
  Timer { interval: 4600; running: true; onTriggered: Qt.quit() }
}
