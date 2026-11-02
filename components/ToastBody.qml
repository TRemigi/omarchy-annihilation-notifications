// annihilation: the toast's body: a soft-edged oval under the text (shaders/toastbody.frag), in place of the card's own rectangle and border, which are off
// while the toast has an oval body (NotificationCard.oval). It lies under the card, a sibling in the slot, a margin larger than the card for the oval's ends and
// its feather; follows the card's scale and opacity; takes no input. The delegate masks it with the same front as the card while the arrival reveals it and
// the exit takes it away, so it comes and goes with the card. The oval's proportions are BodyLogic's.
import QtQuick
import "../BodyLogic.js" as BodyLogic

Item {
  id: root

  required property var target
  property real urgency: 1
  property real vividness: 0.75
  // Pixels per design pixel (Style.space(1)): the feather is 26 design px.
  property real ui: 1
  // The card's own fill colour, which the body keeps.
  property color fill: "black"

  readonly property real margin: 110    // the oval reaches about 25 px past the card's side, and its feather 58 more (design px: a little over that at 1.155)

  anchors.fill: target
  anchors.margins: -margin
  scale: target.scale
  opacity: target.opacity
  transformOrigin: target.transformOrigin
  enabled: false                    // click-through

  ShaderEffect {
    anchors.fill: parent

    property real urgency: root.urgency
    property real vividness: root.vividness
    property real ui: root.ui
    property size size: Qt.size(width, height)
    property vector4d card: Qt.vector4d(root.margin, root.margin, root.target.width, root.target.height)
    property vector4d shape: Qt.vector4d(BodyLogic.OVAL_KX, BodyLogic.OVAL_KY, BodyLogic.OVAL_N, 0)
    property vector4d fill: Qt.vector4d(root.fill.r, root.fill.g, root.fill.b, root.fill.a)

    fragmentShader: Qt.resolvedUrl("../shaders/toastbody.frag.qsb")
  }
}
