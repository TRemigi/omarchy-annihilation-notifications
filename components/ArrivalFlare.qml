// annihilation: the arrival on the card. A front of light leaves the card's centre and crosses it: the card is shown only inside the front
// (the delegate masks it with shaders/cardreveal.frag while `revealing`), its edge flares as the front crosses it and cools behind it
// (shaders/toastflare.frag, the overlay below), and the front goes on out into the screen as ArrivalLayer's ring and halo. When the front
// has crossed the card the look's own rim takes over: `rimGate` rises 0 to 1 for the ToastRim, as the flare's own light falls.
//
// The ring and halo do not leave when the arrival is over: they rest round the card and undulate for as long as the toast is up (ArrivalLayer, which holds them).
//
// The exit is the ring collapsing (ArrivalLogic.exitFront): when the toast leaves (`exiting`, `q` the dissolve's 0 to 1 from SlotMotion) the front
// retreats from where the ring rests to the icon, so the ring is pulled in onto the card and the card dissolves from its far corner into the light (ArrivalLayer.beginExit);
// the flare's afterglow is a ghost of the edge on the side the front has left; and the settled rim fades out as the flare comes up (`rimGate` again).
//
// This item owns the toast's timeline: `p` runs 0 to 1 over the arrival (ArrivalLogic.durationFor, times `slowdown`), the same
// clock the layer uses, from `start`. A toast that is not fresh (restored after a shell restart) does not arrive; with `on` false, or a zero strength, nothing
// is armed and every value below is the settled one, which is stock.
import QtQuick
import "../ArrivalLogic.js" as ArrivalLogic
import "../BodyLogic.js" as BodyLogic

Item {
  id: root

  // The NotificationCard this lights, a sibling in the slot.
  required property var target
  // The ArrivalLayer in the window.
  required property var ring
  property bool on: false
  property real strength: 1
  property real slowdown: 1
  property real urgency: 1
  property string app: ""
  property double timestamp: 0
  // The toast is leaving, and how far through its dissolve it is (SlotMotion.dissolve).
  property bool exiting: false
  property real q: 0

  readonly property real durMs: ArrivalLogic.durationFor(urgency) * slowdown
  property bool armed: on && strength > 0 && ArrivalLogic.isFresh(timestamp, Date.now())
  property double startMs: 0
  property real p: 0

  // Where the wave starts, in the card's pixels: the card's centre, so the arrival is centred on the toast (it used to leave the icon, which sits at the
  // card's left, so the ring seemed centred on the toast's top left corner). The icon's own ring lights as the front reaches it.
  readonly property vector2d origin: Qt.vector2d(target.width / 2, target.height / 2)
  // With an oval body the front is an oval of the toast's proportions (`aspect` stretches the distance vertically; 1 is the circle it was), and has to go as far as the body does.
  readonly property real aspect: target.oval ? BodyLogic.ovalAspect(target.width, target.height) : 1
  readonly property real cardReach: target.oval ? BodyLogic.ovalFrontReach(target.width, target.height) : ArrivalLogic.cardReach(origin.x, origin.y, target.width, target.height)
  // where the exit's front starts (set when the exit begins)
  property real exitFromPx: 0
  readonly property real front: exiting ? ArrivalLogic.exitFront(q, exitFromPx) : (armed ? ArrivalLogic.frontAt(p, cardReach, ring.ringReach) : -1)
  readonly property real settled: exiting || armed ? ArrivalLogic.settle(front, cardReach) : 1
  // the card is masked, and the flare drawn, while the front is crossing it (and the settled rim fades in over the end of that, or out over the start of the exit)
  readonly property bool revealing: (exiting || armed) && front < cardReach + 30
  // the settled rim fades in over the end of the arrival; on the way out it is not faded at all: the delegate masks it with the same front as the card, so it goes
  // exactly as the card does (a separate fade left the border lingering round the edges after the card had collapsed from them)
  readonly property real rimGate: exiting ? 1 : settled
  readonly property real fade: exiting ? ArrivalLogic.exitFade(front, cardReach) : 1 - settled

  // The exit begins: the card's arrival is over (if it was still running) and the ring is told to contract onto the card, from where its front is now (or where it rests).
  onExitingChanged: {
    if (!exiting) return
    var now = Date.now()
    exitFromPx = ArrivalLogic.exitFrom(startMs > 0 ? ArrivalLogic.frontAt(ArrivalLogic.progressOf(startMs, now, durMs), cardReach, ring.ringReach) : 1e9, cardReach, ring.holdReach)
    armed = false
    clock.stop()
    if (on && strength > 0) ring.beginExit(target, exitFromPx, now, ArrivalLogic.exitDurationMs() * slowdown)
  }

  // A card dismissed at once takes its ring with it.
  Component.onDestruction: if (ring) ring.end(target)

  // Armed from the moment the toast exists, so its card is hidden (the front is at the icon, 0) from the first frame; the clock starts, and the
  // layer is told, once the first layout has given the card its size and place.
  Timer {
    id: begin
    interval: 0
    running: root.armed
    onTriggered: {
      root.startMs = Date.now()
      root.ring.begin(root.target, root.origin.x, root.origin.y, root.cardReach, root.urgency, root.app, root.startMs, root.durMs)
      root.p = 0
      clock.start()
    }
  }

  FrameAnimation {
    id: clock
    onTriggered: {
      root.p = ArrivalLogic.progressOf(root.startMs, Date.now(), root.durMs)
      // the card's part is over once the front has crossed it and the settled rim has taken over; the layer carries on by itself
      if (root.p >= 1 || ArrivalLogic.settle(ArrivalLogic.frontAt(root.p, root.cardReach, root.ring.ringReach), root.cardReach) >= 1) { root.armed = false; clock.stop() }
    }
  }

  // the oval body (BodyLogic) reaches 25 px past the card, and its edge flares there too
  readonly property real margin: 56
  anchors.fill: target
  anchors.margins: -margin
  scale: target.scale
  opacity: target.opacity
  transformOrigin: target.transformOrigin
  enabled: false                    // click-through
  visible: revealing || ((armed || exiting) && fade > 0)

  ShaderEffect {
    anchors.fill: parent

    property real strength: root.strength
    property real urgency: root.urgency
    property real radius: root.target.radius
    property real front: Math.max(0, root.front)
    property real fade: root.fade
    property real reverse: root.exiting ? 1 : 0
    property real aspect: root.aspect
    property size size: Qt.size(width, height)
    property vector4d card: Qt.vector4d(root.margin, root.margin, root.target.width, root.target.height)
    property vector2d origin: Qt.vector2d(root.margin + root.origin.x, root.margin + root.origin.y)
    property vector4d shape: root.target.oval ? Qt.vector4d(BodyLogic.OVAL_KX, BodyLogic.OVAL_KY, BodyLogic.OVAL_N, 1) : Qt.vector4d(0, 0, 0, 0)
    property vector3d icon: root.target.iconRing.z > 0
      ? Qt.vector3d(root.margin + root.target.iconRing.x, root.margin + root.target.iconRing.y, root.target.iconRing.z)
      : Qt.vector3d(0, 0, 0)

    fragmentShader: Qt.resolvedUrl("../shaders/toastflare.frag.qsb")
  }
}
