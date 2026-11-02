// annihilation: how one toast slot moves, for the annihilation theme only.
//
// A toast unfolds into the stack when it arrives and folds away when it expires or is dismissed,
// instead of appearing and vanishing. `presence` runs 0 to 1 on entry and 1 to 0 on exit, and the
// slot binds its height, its card's opacity and scale, and a spacing trim to the values below, so
// the stack makes room for a new toast and closes up behind a leaving one.
//
// Timing: entry 480 ms on an ease-out cubic, exit 300 ms on the theme's `exhale` curve; both are
// multiplied by `slowdown` (the user's `motion_slowdown` in annihilation-notifications-fork.conf),
// which is also how to check that the motion is running at all: set it to 4 and it is unmistakable.
// The first version used the theme's `tendril` curve over 340 ms; measured in a real Quickshell it was
// 75% done after five frames (80 ms) and read as a pop, not an unfold, so it is slower and gentler now.
//
// With `fx` false (any other theme) nothing animates: presence stays 1 and leave() calls back at
// once, which is what stock Omarchy does.
import QtQuick
import "../ArrivalLogic.js" as ArrivalLogic

Item {
  id: root

  property bool fx: false
  // The arrival and the exit: the card is not faded or scaled (a front of light reveals it and takes it away, see ArrivalFlare.qml); on entry only
  // the slot opens, a little faster, so the stack has made room by the time the light crosses the card; on exit the card dissolves into the
  // light first (`dissolve` runs 0 to 1) and the slot folds shut when that is mostly done.
  property bool reveal: false
  // The column's spacing, so the gap a slot adds can be folded away with the slot.
  property real spacing: 8
  // Multiplies both durations; 1 is the designed speed.
  property real slowdown: 1

  property real presence: 1
  property bool leaving: false
  property real dissolve: 0

  readonly property int enterMs: Math.round((reveal ? 300 : 480) * slowdown)
  readonly property int exitMs: Math.round(300 * slowdown)
  readonly property int dissolveMs: Math.round(ArrivalLogic.exitDurationMs() * slowdown)

  // What the slot binds to.
  readonly property real heightFactor: presence
  readonly property real cardOpacity: reveal ? 1 : presence
  readonly property real cardScale: reveal ? 1 : 0.94 + 0.06 * presence
  readonly property real spacingTrim: -spacing * (1 - presence)
  readonly property bool clipping: presence < 1

  property var pendingDone: null

  // Emitted when a toast starts to go (not when nothing animates): the moment its spores are released. With the dissolve that is when the card
  // starts to come apart, a quarter of the way through, not at the very start.
  signal leaveStarted()

  function enter() {
    if (!fx) return
    enterAnim.stop()
    presence = 0
    enterAnim.start()
  }

  // Fold away, then call `done`. Calls `done` at once when nothing animates; a second call while
  // leaving is ignored (the first one's `done` is still coming).
  function leave(done) {
    if (leaving) return
    if (!fx) {
      if (done) done()
      return
    }
    leaving = true
    pendingDone = done
    enterAnim.stop()
    if (reveal) {
      dissolve = 0
      dissolveAnim.restart()
      sporeTimer.interval = Math.round(0.25 * dissolveMs)
      sporeTimer.restart()
    } else {
      leaveStarted()
      exitAnim.restart()
    }
  }

  // The card dissolving into the light; the slot folds shut at EXIT_FOLD_AT of it.
  NumberAnimation {
    id: dissolveAnim
    target: root
    property: "dissolve"
    from: 0
    to: 1
    duration: root.dissolveMs
  }
  onDissolveChanged: if (leaving && reveal && dissolve >= ArrivalLogic.EXIT_FOLD_AT && !exitAnim.running && presence >= 1) exitAnim.restart()
  Timer { id: sporeTimer; onTriggered: root.leaveStarted() }

  NumberAnimation {
    id: enterAnim
    target: root
    property: "presence"
    to: 1
    duration: root.enterMs
    easing.type: Easing.BezierSpline
    easing.bezierCurve: [0.33, 1, 0.68, 1, 1, 1]
  }

  NumberAnimation {
    id: exitAnim
    target: root
    property: "presence"
    to: 0
    duration: root.exitMs
    easing.type: Easing.BezierSpline
    easing.bezierCurve: [0.5, 0, 0.75, 1, 1, 1]
    onFinished: {
      var done = root.pendingDone
      root.pendingDone = null
      if (done) done()
    }
  }
}
