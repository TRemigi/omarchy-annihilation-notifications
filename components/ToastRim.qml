// annihilation: the light on a toast, drawn by shaders/toastrim.frag over a card: an iridescent rim with a prism
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

  property real energy: 1
  property real time: 0
  readonly property real margin: 20

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
  }

  SequentialAnimation {
    id: igniteAnim
    PauseAnimation { duration: Math.round(120 * root.slowdown) }
    NumberAnimation { target: root; property: "energy"; to: 1; duration: Math.round(1100 * root.slowdown); easing.type: Easing.OutCubic }
  }

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

    fragmentShader: Qt.resolvedUrl("../shaders/toastrim.frag.qsb")
  }
}
