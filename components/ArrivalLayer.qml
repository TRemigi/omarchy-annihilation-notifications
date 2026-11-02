// annihilation: the arrival outside the cards: a ring of light that leaves each new toast's own outline and travels out, and a halo
// that hugs it, drawn by shaders/toastring.frag. It lives in the popup window, under the toast column (so each card hides the middle
// of its own light), over the whole window, because the ring outlasts the card's unfolding and the wave travels about 700 px from the icon
// (a layer sized to the card cut it off in a straight line, seen in a recording); it renders at half resolution and only while an arrival runs. It replaces the theme's
// old arrival ring, whose source was a fixed box near the corner; here every arrival carries its card, so the light is the card's shape.
//
// A toast's ArrivalFlare calls begin() with its card. Up to three arrivals are drawn at once; a burst is thinned so it does not stack
// into a flash. The layer is invisible, and costs nothing, while there are none, renders at half resolution (the light is soft) and takes no input.
import QtQuick
import "../ArrivalLogic.js" as ArrivalLogic

Item {
  id: root

  // The user's `arrival` setting, 0 to 2: how strong the arrival's light is; 0 means none.
  property real strength: 1
  property real cornerRadius: 4
  property real seed: Math.random() * 100
  // The whole window's height, for the ring's reach.
  property real screenHeight: 1080
  readonly property real ringReach: ArrivalLogic.ringReachFor(screenHeight)

  // { item (the card), x, y, w, h (the card in this layer's px), ix, iy (the icon, in the card's px), cardReach, urgency, amp, salt, start, dur }, oldest first
  property var events: []
  property real nowMs: 0
  readonly property bool active: events.length > 0
  readonly property int maxEvents: 3

  enabled: false                      // click-through

  function live(now) {
    return events.filter(function(e) { return now - e.start < e.dur })
  }

  // A card arrives: `item` is the NotificationCard, (ix, iy) its icon in its own pixels, `start` the moment (ms) and `dur` the length (ms)
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
      salt: (list.length + Math.floor(now / 1000)) % 7 * 1.3, start: start, dur: dur
    })
    events = list.slice(-maxEvents)
    nowMs = now
  }

  // A card is leaving: the same wave played backwards (ArrivalLogic.exitProgress), faster, so the ring contracts onto the card and brightens as it gets there.
  // `start` and `dur` are the dissolve's, which the card's own flare shares.
  function beginExit(item, ix, iy, cardReach, urgency, app, start, dur) {
    if (!(strength > 0)) return
    var now = Date.now()
    var list = live(now)
    var p = item.mapToItem(root, 0, 0)
    list.push({
      item: item, x: p.x, y: p.y, w: item.width, h: item.height, ix: ix, iy: iy, cardReach: cardReach, exit: true, p0: ArrivalLogic.exitStart(cardReach, ringReach),
      urgency: urgency, amp: ArrivalLogic.amplitudeFor(app, urgency, 1e9), salt: (list.length + Math.floor(now / 1000)) % 7 * 1.3, start: start, dur: dur
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

  function progressAt(i, now) {
    var e = events[i], t = ArrivalLogic.progressOf(e.start, now, e.dur)
    return e.exit ? ArrivalLogic.exitProgress(t, e.p0) : t
  }
  function rectAt(i, now) {
    if (i >= events.length || now < 0) return Qt.vector4d(0, 0, 0, 0)
    var e = events[i]
    return Qt.vector4d(e.x, e.y, e.w, e.h)
  }
  function srcAt(i, now) {
    if (i >= events.length || now < 0) return Qt.vector4d(0, 0, 0, 0)
    var e = events[i]
    return Qt.vector4d(e.x + e.ix, e.y + e.iy, e.cardReach, ArrivalLogic.frontAt(progressAt(i, now), e.cardReach, ringReach))
  }
  function evAt(i, now) {
    if (i >= events.length || now < 0) return Qt.vector4d(0, 1, 0, 0)
    var e = events[i]
    return Qt.vector4d(progressAt(i, now), e.urgency, e.amp, e.salt)
  }

  FrameAnimation {
    running: root.active
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
    property real reach: root.ringReach
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

    fragmentShader: Qt.resolvedUrl("../shaders/toastring.frag.qsb")
  }
}
