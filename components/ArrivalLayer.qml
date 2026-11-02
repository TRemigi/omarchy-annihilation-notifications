// annihilation: the arrival outside the cards: a ring of light that leaves each new toast's own outline and travels out, and a halo
// that hugs it, drawn by shaders/toastring.frag. It lives in the popup window, under the toast column (so each card hides the middle
// of its own light), over the whole window, because the ring outlasts the card's unfolding and the wave travels some 500 px from the card's centre
// (a layer sized to the card cut it off in a straight line, seen in a recording); it renders at half resolution and only while an arrival runs. It replaces the theme's
// old arrival ring, whose source was a fixed box near the corner; here every arrival carries its card, so the light is the card's shape.
//
// The ring does not fade away when the arrival is over: it comes to rest a short way (`holdReach`) from the card's outline and lingers there, undulating, for as long
// as the toast is up (the event is "held"); when the toast leaves, beginExit() swaps it for an exit event that pulls it in onto the card. A toast dismissed at once
// (click, IPC) takes its ring with it (end()).
//
// A toast's ArrivalFlare calls begin() with its card. Up to three rings are drawn at once (the oldest goes first); a burst is thinned so it does not stack
// into a flash. The layer is invisible, and costs nothing, while there are none, renders at half resolution (the light is soft) and takes no input.
import QtQuick
import "../ArrivalLogic.js" as ArrivalLogic
import "../BodyLogic.js" as BodyLogic

Item {
  id: root

  // The user's `arrival` setting, 0 to 2: how strong the arrival's light is; 0 means none.
  property real strength: 1
  property real cornerRadius: 4
  // The toasts have an oval body (BodyLogic): nothing is then hidden behind a card, the body covers the glow itself, and the halo hugs the oval.
  property bool oval: false
  readonly property vector4d shape: oval ? Qt.vector4d(BodyLogic.OVAL_KX, BodyLogic.OVAL_KY, BodyLogic.OVAL_N, 1) : Qt.vector4d(0, 0, 0, 0)
  property real seed: Math.random() * 100
  // The whole window's height, for the ring's reach.
  property real screenHeight: 1080
  // How fast the front runs (the arrival's timing), and how far from the outline the ring rests (the arrival's size on screen).
  readonly property real ringReach: ArrivalLogic.ringReachFor(screenHeight)
  readonly property real holdReach: ArrivalLogic.holdReachFor(screenHeight)

  // The ring is an oval, as big as ArrivalLogic.ringScale of the front says (a fraction of the resting size: semi-axes half the card plus 0.55 (across) / 0.8 (up and down) of `holdReach`).
  // { item (the card), x, y, w, h (the card in this layer's px), ix, iy (the wave's origin, the card's centre, in the card's px), cardReach, urgency, amp, salt, start, dur,
  //   hold (stays after dur until it is replaced or ended), exit (leaving; with p0 and s0, the arrival's progress and the ring's size then, and from, the front's radius then) }, oldest first
  property var events: []
  property real nowMs: 0
  // seconds, wrapped, for the shader's undulation
  readonly property real shaderTime: (nowMs % 600000) / 1000
  readonly property bool active: events.length > 0
  readonly property int maxEvents: 3

  enabled: false                      // click-through

  function live(now) {
    return events.filter(function(e) { return e.hold ? e.item !== null : now - e.start < e.dur })
  }

  // The event of a card that is up: its ring, resting or on its way.
  function heldOf(item) {
    for (var i = 0; i < events.length; i++) if (events[i].item === item && events[i].hold) return events[i]
    return null
  }

  // The card has gone without an exit (dismissed at once): its ring goes with it.
  function end(item) {
    var kept = events.filter(function(e) { return e.item !== item })
    if (kept.length !== events.length) events = kept
  }

  // A card arrives: `item` is the NotificationCard, (ix, iy) the wave's origin in its own pixels, `start` the moment (ms) and `dur` the length (ms)
  // it shares with the card's own flare.
  function begin(item, ix, iy, cardReach, urgency, app, start, dur) {
    if (!(strength > 0)) return
    var now = Date.now()
    var list = live(now)
    var last = list.length > 0 ? list[list.length - 1] : null
    var p = item.mapToItem(root, 0, 0)
    list.push({
      item: item, x: p.x, y: p.y, w: item.width, h: item.height, ix: ix, iy: iy, cardReach: cardReach,
      urgency: urgency, amp: ArrivalLogic.amplitudeFor(app, urgency, last ? start - last.start : 1e9),
      salt: (list.length + Math.floor(now / 1000)) % 7 * 1.3, start: start, dur: dur, hold: true
    })
    events = list.slice(-maxEvents)
    nowMs = now
  }

  // A card is leaving: its ring (resting, or still on its way) is pulled in onto the card (ArrivalLogic.exitFront), brightening as it goes, while the card dissolves
  // into it. `start` and `dur` are the dissolve's, which the card's own flare shares; `from` is the front's radius at the start (ArrivalLogic.exitFrom). A toast with
  // no ring (it did not arrive: restored after a shell restart, or its ring was the oldest of a crowd) has nothing to pull in.
  function beginExit(item, from, start, dur) {
    var held = heldOf(item)
    if (!held) return
    var now = Date.now()
    var list = live(now).filter(function(e) { return e !== held })
    list.push({
      item: item, x: held.x, y: held.y, w: held.w, h: held.h, ix: held.ix, iy: held.iy, cardReach: held.cardReach, exit: true, from: from,
      p0: ArrivalLogic.progressOf(held.start, now, held.dur),
      s0: ArrivalLogic.ringScale(ArrivalLogic.frontAt(ArrivalLogic.progressOf(held.start, now, held.dur), held.cardReach, ringReach)),
      urgency: held.urgency, amp: held.amp, salt: held.salt, start: start, dur: dur
    })
    events = list.slice(-maxEvents)
    nowMs = now
  }

  // Follow the card while it exists: the stack moves as toasts come and go.
  function refresh(e) {
    var it = e.item
    if (!it) return
    try {
      var p = it.mapToItem(root, 0, 0)
      e.x = p.x; e.y = p.y; e.w = it.width; e.h = it.height
    } catch (err) { e.item = null }
  }

  function tick() {
    var now = Date.now()
    var kept = live(now)
    if (kept.length !== events.length) events = kept
    for (var i = 0; i < events.length; i++) refresh(events[i])
    nowMs = now
  }

  // The arrival's progress (1 once it has arrived: the held state; an exit keeps the progress it left at).
  function progressAt(i, now) {
    var e = events[i]
    return e.exit ? e.p0 : ArrivalLogic.progressOf(e.start, now, e.dur)
  }
  function frontOf(i, now) {
    var e = events[i]
    return e.exit ? ArrivalLogic.exitFront(ArrivalLogic.progressOf(e.start, now, e.dur), e.from) : ArrivalLogic.frontAt(progressAt(i, now), e.cardReach, ringReach)
  }
  function rectAt(i, now) {
    if (i >= events.length || now < 0) return Qt.vector4d(0, 0, 0, 0)
    var e = events[i]
    return Qt.vector4d(e.x, e.y, e.w, e.h)
  }
  function srcAt(i, now) {
    if (i >= events.length || now < 0) return Qt.vector4d(0, 0, 0, 0)
    var e = events[i]
    var f = frontOf(i, now)
    return Qt.vector4d(e.x + e.ix, e.y + e.iy, e.exit ? ArrivalLogic.ringScaleExit(f, e.from, e.s0) : ArrivalLogic.ringScale(f), f)
  }
  function evAt(i, now) {
    if (i >= events.length || now < 0) return Qt.vector4d(0, 1, 0, 0)
    var e = events[i]
    // pulled in, the ring brightens
    var lift = e.exit ? 1 + 0.7 * ArrivalLogic.clamp01(2 * ArrivalLogic.progressOf(e.start, now, e.dur)) : 1
    return Qt.vector4d(progressAt(i, now), e.urgency, e.amp * lift, e.salt)
  }

  // Frame by frame while anything moves quickly (an arrival under way, a ring being pulled in); at 30 Hz while rings only rest, which is slow enough not to show.
  readonly property bool busy: events.some(function(e) { return e.exit || (e.hold && nowMs - e.start < e.dur) })
  FrameAnimation {
    running: root.busy
    onTriggered: root.tick()
  }
  Timer {
    interval: 33
    repeat: true
    running: root.active && !root.busy
    onTriggered: root.tick()
  }

  ShaderEffect {
    anchors.fill: parent
    visible: root.active

    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(Math.max(1, Math.round(width * 0.5)), Math.max(1, Math.round(height * 0.5)))

    property real seed: root.seed
    property real strength: root.strength
    property real reach: root.holdReach
    property real time: root.shaderTime
    property real radius: root.cornerRadius
    property size resolution: Qt.size(width, height)
    property vector4d rect0: root.rectAt(0, root.nowMs)
    property vector4d rect1: root.rectAt(1, root.nowMs)
    property vector4d rect2: root.rectAt(2, root.nowMs)
    property vector4d src0: root.srcAt(0, root.nowMs)
    property vector4d src1: root.srcAt(1, root.nowMs)
    property vector4d src2: root.srcAt(2, root.nowMs)
    property vector4d ev0: root.evAt(0, root.nowMs)
    property vector4d ev1: root.evAt(1, root.nowMs)
    property vector4d ev2: root.evAt(2, root.nowMs)
    property vector4d shape: root.shape

    fragmentShader: Qt.resolvedUrl("../shaders/toastring.frag.qsb")
  }
}
