// A stand-in toast stack (plain rectangles, the same slot bindings as the real delegate in
// Service.qml) rendered offscreen, to judge the motion and the layout math: a toast arrives on top
// of two settled ones, then the middle one leaves. Saves PNG frames to the directory in argument
// FRAMES (an environment variable). Run through test/motion-filmstrip.sh.
import QtQuick
import QtQuick.Layouts
import QtQml
import "../components"

Item {
  id: root
  width: 440; height: 330

  Rectangle { anchors.fill: parent; color: "#1c1a12" }

  ListModel { id: model }

  ColumnLayout {
    id: column
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 16
    spacing: 8

    Repeater {
      model: model
      delegate: Item {
        id: slot
        required property string label
        property alias motion: motion
        Layout.preferredWidth: 380
        Layout.alignment: Qt.AlignRight
        implicitHeight: card.implicitHeight * motion.heightFactor
        Layout.bottomMargin: motion.spacingTrim
        clip: motion.clipping

        SlotMotion { id: motion; fx: true; spacing: 8 }
        Component.onCompleted: motion.enter()

        Rectangle {
          id: card
          anchors.right: parent.right
          width: 380
          implicitHeight: 64
          radius: 4
          color: "#242015"
          border.width: 2
          border.color: "#61A0A8"
          opacity: motion.cardOpacity
          scale: motion.cardScale
          transformOrigin: Item.TopRight
          Text { anchors.centerIn: parent; text: slot.label; color: "#D2C3A4"; font.pixelSize: 15 }
        }
      }
    }
  }

  function snap(name) {
    root.grabToImage(function(r) { r.saveToFile(Qt.application.arguments.length > 0 ? frames + "/" + name + ".png" : name + ".png") })
  }
  property string frames: ""

  Component.onCompleted: {
    frames = Qt.application.arguments[Qt.application.arguments.length - 1]
    model.append({ label: "older toast B" })
    model.append({ label: "older toast A" })
  }

  // Timeline (ms): the first two settle, one arrives at 700, the middle one leaves at 1600.
  property var shots: [
    [650, "a0_before"],
    [700, "b0_arrive"], [760, "b1"], [820, "b2"], [900, "b3"], [1000, "b4"], [1200, "b5_settled"],
    [1600, "c0_leave"], [1680, "c1"], [1760, "c2"], [1840, "c3"], [1960, "c4_closed"]
  ]
  Instantiator {
    model: root.shots
    delegate: Timer {
      required property var modelData
      interval: modelData[0]; running: true
      onTriggered: root.snap(modelData[1])
    }
  }
  Timer { interval: 700; running: true; onTriggered: model.insert(0, { label: "NEW toast" }) }
  Timer {
    interval: 1600; running: true
    onTriggered: { var item = null; for (var i = 0; i < column.children.length; i++) if (column.children[i].motion && column.children[i].label === "older toast B") item = column.children[i]
      if (item) item.motion.leave(function() { for (var j = 0; j < model.count; j++) if (model.get(j).label === "older toast B") { model.remove(j); break } }) }
  }
  Timer { interval: 2300; running: true; onTriggered: Qt.quit() }
}
