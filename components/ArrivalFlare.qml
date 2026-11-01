// annihilation: the arrival on the card. A front of light leaves the card's icon and crosses it: the card is shown only inside the front
// (the delegate masks it with shaders/cardreveal.frag while `revealing`), its edge flares as the front crosses it and cools behind it
// (shaders/toastflare.frag, the overlay below), and the front goes on out into the screen as ArrivalLayer's ring and halo. When the front
// has crossed the card the look's own rim takes over: `rimGate` rises 0 to 1 for the ToastRim, as the flare's own light falls.
//
// This item owns the toast's timeline: `p` runs 0 to 1 over the arrival (ArrivalLogic.durationFor, times `slowdown`), the same
// clock the layer uses, from `start`. A toast that is not fresh (restored after a shell restart) does not arrive; with `on` false, or a zero strength, nothing
// is armed and every value below is the settled one, which is stock.
import QtQuick
import "../ArrivalLogic.js" as ArrivalLogic

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

  readonly property real durMs: ArrivalLogic.durationFor(urgency) * slowdown
  property bool armed: on && strength > 0 && ArrivalLogic.isFresh(timestamp, Date.now())
  property double startMs: 0
  property real p: 0

  // Where the icon is, in the card's pixels (a toast with no icon starts from its left, a little in).
  readonly property vector2d cardIcon: target.iconRing.z > 0 ? Qt.vector2d(target.iconRing.x, target.iconRing.y) : Qt.vector2d(32, target.height / 2)
  readonly property real cardReach: ArrivalLogic.cardReach(cardIcon.x, cardIcon.y, target.width, target.height)
  readonly property real front: armed ? ArrivalLogic.frontAt(p, cardReach, ring.ringReach) : -1
  readonly property real settled: armed ? ArrivalLogic.settle(front, cardReach) : 1
  // the card is masked, and the flare drawn, while the front is crossing it (and the settled rim fades in over the end of that)
  readonly property bool revealing: armed && front < cardReach + 30
  readonly property real rimGate: settled
  readonly property real fade: 1 - settled

  // Armed from the moment the toast exists, so its card is hidden (the front is at the icon, 0) from the first frame; the clock starts, and the
  // layer is told, once the first layout has given the card its size and place.
  Timer {
    id: begin
    interval: 0
    running: root.armed
    onTriggered: {
      root.startMs = Date.now()
      root.ring.begin(root.target, root.cardIcon.x, root.cardIcon.y, root.cardReach, root.urgency, root.app, root.startMs, root.durMs)
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

  readonly property real margin: 40
  anchors.fill: target
  anchors.margins: -margin
  scale: target.scale
  opacity: target.opacity
  transformOrigin: target.transformOrigin
  enabled: false                    // click-through
  visible: revealing || (armed && fade > 0)

  ShaderEffect {
    anchors.fill: parent

    property real strength: root.strength
    property real urgency: root.urgency
    property real radius: root.target.radius
    property real front: Math.max(0, root.front)
    property real fade: root.fade
    property size size: Qt.size(width, height)
    property vector4d card: Qt.vector4d(root.margin, root.margin, root.target.width, root.target.height)
    property vector3d icon: root.target.iconRing.z > 0
      ? Qt.vector3d(root.margin + root.target.iconRing.x, root.margin + root.target.iconRing.y, root.target.iconRing.z)
      : Qt.vector3d(0, 0, 0)

    fragmentShader: Qt.resolvedUrl("../shaders/toastflare.frag.qsb")
  }
}
