// annihilation: the light on a toast in the glow look (`look=glow`), drawn by shaders/toastglow.frag over a card: the
// window glow's own light, hugging the card as it hugs a window, and the arrival.
//
// It lies over the card with a margin for the halo, follows its size, scale and opacity, takes no input, and draws nothing
// but light. The shader needs the toast's place on the screen (the glow is a field over the whole screen, and the overlay
// window is the screen), so it re-reads the position with the clock, a few dozen times a second; the colour changes
// slowly enough that a frame of lag in the position is invisible.
//
// The arrival: `wave` runs 0 to 1 and the front of light it makes leaves the icon, crossing the card; the card is shown only
// inside it (the delegate masks the card layer with cardreveal.frag using `front`), and the light is nothing beyond it and flares
// as it crosses an edge. Settled, `wave` is -1. The duration is multiplied by `slowdown`.
import QtQuick
import "../GlowLogic.js" as GlowLogic

Item {
  id: root

  // The NotificationCard this lights, a sibling in the slot.
  required property var target
  // The GlowClock.
  required property var glow
  // The overlay window's size: the screen, in px.
  property size screenSize: Qt.size(1920, 1080)
  property real urgency: 1          // NotificationUrgency: 0 low, 1 normal, 2 critical
  property real slowdown: 1
  // The toast's band is this much shallower than a window's (a 78 px card with a window's band reads as a bevelled frame), and
  // never deeper than `maxDepth` however deep the windows' is set (the theme's slider goes to 2.5; the mock-up was 0.13).
  property real depthRatio: 0.62
  property real maxDepth: 0.2

  property real wave: -1
  readonly property bool arriving: visible && wave >= 0
  readonly property real margin: 48

  anchors.fill: target
  anchors.margins: -margin
  scale: target.scale
  opacity: target.opacity
  transformOrigin: target.transformOrigin
  enabled: false                    // click-through

  // Where the icon ring goes, in the overlay's own pixels (the card sits `margin` in from each side), and in the card's.
  readonly property vector3d icon: target.iconRing.z > 0
    ? Qt.vector3d(margin + target.iconRing.x, margin + target.iconRing.y, target.iconRing.z)
    : Qt.vector3d(0, 0, 0)
  readonly property vector2d cardIcon: target.iconRing.z > 0 ? Qt.vector2d(target.iconRing.x, target.iconRing.y) : Qt.vector2d(32, target.height / 2)
  readonly property real reach: GlowLogic.arrivalReach(cardIcon.x, cardIcon.y, target.width, target.height)
  readonly property real front: wave >= 0 ? wave * reach : -1

  property real time: 0
  property point origin: Qt.point(0, 0)
  function sync() {
    time = glow.clockNow()
    var p = root.mapToItem(null, 0, 0)
    origin = Qt.point(p.x, p.y)
  }
  Timer {
    interval: 33
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: root.sync()
  }

  function arrive() { waveAnim.restart() }

  NumberAnimation {
    id: waveAnim
    target: root
    property: "wave"
    from: 0
    to: 1
    duration: Math.round(1500 * root.slowdown)
    easing.type: Easing.OutQuad
    onFinished: root.wave = -1
  }

  ShaderEffect {
    anchors.fill: parent

    property real time: root.time
    property real intensity: root.glow.intensity
    property real seed: root.glow.seed
    property real rimWidth: GlowLogic.rimWidthFor(root.screenSize.height)
    property real depth: GlowLogic.toastDepth(root.glow.depth, root.depthRatio, root.maxDepth)
    property real urgency: root.urgency
    property real radius: root.target.radius
    property real front: root.front
    property size resolution: root.screenSize
    property size origin: Qt.size(root.origin.x, root.origin.y)
    property size size: Qt.size(width, height)
    property vector4d card: Qt.vector4d(root.margin, root.margin, root.target.width, root.target.height)
    property vector3d icon: root.icon

    fragmentShader: Qt.resolvedUrl("../shaders/toastglow.frag.qsb")
  }
}
