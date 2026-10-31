// annihilation: the spores of toasts that have just left, drawn by shaders/toastspores.frag. This lives in the popup
// window, over the whole stack, because a toast's own item is gone as soon as it has folded away (300 ms) and its
// spores last a second and a half. A toast that leaves calls burst() with where its card was, in this layer's pixels;
// up to four bursts are drawn at once. The layer is invisible, and costs nothing, while there are none. It takes no input.
import QtQuick

Item {
  id: root

  // 0 to 1: the user's `spore_amount`; 0 means no spores at all.
  property real amount: 1

  property var bursts: []             // { x, y, w, h, start (ms), seed, urgency }, oldest first
  property real nowMs: 0
  readonly property bool active: bursts.length > 0
  readonly property int lifeMs: 2200  // a burst is over by then (the shader draws nothing after 2.2 s)
  readonly property int maxBursts: 4

  enabled: false                      // click-through

  function live(now) {
    return bursts.filter(function(b) { return now - b.start < lifeMs })
  }

  // A card that was at x, y, w, h (this layer's pixels) is dissolving; urgency is its NotificationUrgency.
  function burst(x, y, w, h, urgency) {
    if (!(amount > 0)) return
    var now = Date.now()
    var list = live(now)
    list.push({ x: x, y: y, w: w, h: h, start: now, seed: Math.floor(Math.random() * 1000) / 10 + list.length * 0.37, urgency: urgency })
    bursts = list.slice(-maxBursts)
    nowMs = now
  }

  function tick() {
    var now = Date.now()
    nowMs = now
    var kept = live(now)
    if (kept.length !== bursts.length) bursts = kept
  }

  // What the shader is told about the i-th burst: where its card was, and its age (negative for none).
  function rectAt(i) {
    var b = i < bursts.length ? bursts[i] : null
    return b ? Qt.vector4d(b.x, b.y, b.w, b.h) : Qt.vector4d(0, 0, 0, 0)
  }
  function stateAt(i, now) {
    var b = i < bursts.length ? bursts[i] : null
    return b ? Qt.vector4d((now - b.start) / 1000, b.seed, b.urgency, 0) : Qt.vector4d(-1, 0, 1, 0)
  }

  FrameAnimation {
    running: root.active
    onTriggered: root.tick()
  }

  ShaderEffect {
    anchors.fill: parent
    visible: root.active

    property real amount: root.amount
    property size size: Qt.size(width, height)
    property vector4d rect0: root.rectAt(0)
    property vector4d rect1: root.rectAt(1)
    property vector4d rect2: root.rectAt(2)
    property vector4d rect3: root.rectAt(3)
    property vector4d state0: root.stateAt(0, root.nowMs)
    property vector4d state1: root.stateAt(1, root.nowMs)
    property vector4d state2: root.stateAt(2, root.nowMs)
    property vector4d state3: root.stateAt(3, root.nowMs)

    fragmentShader: Qt.resolvedUrl("../shaders/toastspores.frag.qsb")
  }
}
