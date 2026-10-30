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
  function addToast() {
    var id = nextId++
    console.log("PROBE insert " + id + " themed=" + svc.themed + " slowdown=" + svc.motionSlowdown)
    svc.popupModel.insert(0, { id: id, originalId: id, app: "Signal", appIcon: "", summary: "probe " + id, body: "body", image: "", glyph: "", execArgv: "", urgency: 1, expireTimeout: 0, timestamp: Date.now() })
  }
  function parse(label, raw) { console.log("PROBE parse " + label + " -> " + svc.parseSlowdown(raw)) }

  Component.onCompleted: {
    parse("empty", ""); parse("plain", "motion_slowdown=2"); parse("spaced", "  motion_slowdown = 4  ")
    parse("decimal", "motion_slowdown=0.5"); parse("too small", "motion_slowdown=0.1"); parse("too big", "motion_slowdown=99")
    parse("junk", "motion_slowdown=abc"); parse("other keys", "x=1\nmotion_slowdown=3\ny=2\n"); parse("no key", "x=1")
    parse("trailing junk", "motion_slowdown=3x")
  }

  Timer { interval: 400; running: true; onTriggered: console.log("PROBE early themed=" + svc.themed) }
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
