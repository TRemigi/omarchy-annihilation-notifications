// annihilation: the light on a toast, drawn by shaders/toastrim.frag (or toastgrowth.frag, `look: "growth"`) over a card: an iridescent rim with a prism
// spill inside and a faint halo outside, and a ring round the app icon. It lies over the card with a margin for
// the halo, follows its size, scale and opacity, takes no input, and draws nothing but light.
//
// The rim ignites bright when the toast arrives and cools to its settled strength over about a second (the
// arrival ring becoming the card), then drifts very slowly. Both times are multiplied by `slowdown`.
import QtQuick

Item {
  id: root

  // The NotificationCard this lights, a sibling in the slot; the ring needs to know where its icon is.
  required property var target
  property real urgency: 1          // NotificationUrgency: 0 low, 1 normal, 2 critical
  property real slowdown: 1
  property real vividness: 0.75
  // The fraction of the toast's life left, 1 down to 0, or negative for none (critical toasts never expire).
  property real remaining: -1
  // 0 to 1: the faint spores off the card's left edge (the user's spore_amount); 0 for none.
  property real spores: 1
  // "blend" (the rim, toastrim.frag) or "growth" (toastgrowth.frag: a living outline, lichen, veins that grow out on arrival).
  property string look: "blend"
  // Growth only: per toast, so no two grow alike; and how far through its life the toast is (0 to 1, never back), which the roots
  // grow over: each starts and finishes at its own moment, the last just before the countdown ends. It follows `remaining`, so it
  // freezes while the toast is hovered; an update restarts the countdown but the roots do not shrink. A toast that never
  // expires (critical) is given a nominal eight seconds.
  property real seed: Math.random() * 100
  property real growth: 0
  onRemainingChanged: if (remaining >= 0) growth = Math.max(growth, 1 - remaining)

  property real energy: 1
  property real time: 0
  readonly property real margin: 110    // the halo needs 20, the faint spores 56, and the Growth look's roots up to about 100

  anchors.fill: target
  anchors.margins: -margin
  scale: target.scale
  opacity: target.opacity
  transformOrigin: target.transformOrigin
  enabled: false                    // click-through

  // Where the icon ring goes, in the overlay's own pixels (the card sits `margin` in from each side). The
  // card says whether there is an icon and how big a ring it needs.
  readonly property vector3d icon: target.iconRing.z > 0
    ? Qt.vector3d(margin + target.iconRing.x, margin + target.iconRing.y, target.iconRing.z)
    : Qt.vector3d(0, 0, 0)

  function ignite() {
    igniteAnim.stop()
    energy = 2.2
    igniteAnim.start()
    growth = 0
    if (remaining < 0) growAnim.restart()
  }

  // For a toast with no countdown: the roots grow over a nominal eight seconds (times `slowdown`).
  NumberAnimation { id: growAnim; target: root; property: "growth"; from: 0; to: 1; duration: Math.round(8000 * root.slowdown) }

  // The slow drift of the colour, at a few frames a second: it only needs to be smooth, not fast.
  Timer {
    interval: 66
    running: root.visible
    repeat: true
    onTriggered: root.time += 0.066
  }

  ShaderEffect {
    anchors.fill: parent

    property real time: root.time
    property real energy: root.energy
    property real vividness: root.vividness
    property real urgency: root.urgency
    property real radius: root.target.radius
    property size size: Qt.size(width, height)
    property vector4d card: Qt.vector4d(root.margin, root.margin, root.target.width, root.target.height)
    property vector3d icon: root.icon
    property real remaining: root.remaining
    property real spores: root.spores
    property real seed: root.seed
    property real growth: root.growth

    fragmentShader: Qt.resolvedUrl(root.look === "growth" ? "../shaders/toastgrowth.frag.qsb" : "../shaders/toastrim.frag.qsb")
  }
}
