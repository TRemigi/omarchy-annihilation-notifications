// Offscreen test of components/SlotMotion.qml's timing and callbacks. Prints lines the shell test
// (motion-test.sh) checks. Run only through that script.
import QtQuick
import "../components"

Item {
  id: root
  width: 10; height: 10
  property int doneCalls: 0
  property var log: []
  function say(s) { console.log("T " + s) }

  SlotMotion { id: stock; fx: false }
  SlotMotion { id: themed; fx: true }
  SlotMotion { id: slow; fx: true; slowdown: 4 }

  Component.onCompleted: {
    // Stock: nothing animates, callbacks are immediate.
    stock.enter()
    say("stock presence after enter " + stock.presence)
    var called = 0
    stock.leave(function() { called++ })
    say("stock leave called back at once " + called)
    say("stock leaving " + stock.leaving)
    say("stock values " + stock.heightFactor + " " + stock.cardOpacity + " " + stock.cardScale + " " + stock.spacingTrim + " " + stock.clipping)

    // Themed: enter starts at 0 straight away.
    say("themed durations " + themed.enterMs + " " + themed.exitMs)
    say("slow durations " + slow.enterMs + " " + slow.exitMs)
    slow.enter()
    themed.enter()
    say("themed presence right after enter " + themed.presence)
    say("themed values at 0 " + themed.heightFactor + " " + themed.cardOpacity + " " + themed.cardScale + " " + themed.spacingTrim + " " + themed.clipping)
    enterTimer.start()
  }

  property var enterSamples: []
  Timer {
    id: enterTimer
    interval: 20; repeat: true
    property int ticks: 0
    onTriggered: {
      ticks++
      root.enterSamples.push(themed.presence)
      if (ticks === 4) root.say("themed presence at ~80ms " + themed.presence)
      if (ticks === 8) root.say("themed presence at ~160ms " + themed.presence)
      if (ticks === 24) root.say("slow presence at ~480ms " + slow.presence)
      if (ticks >= 34) {           // ~680 ms: well past the 480 ms entry
        stop()
        var mono = true
        for (var i = 1; i < root.enterSamples.length; i++) if (root.enterSamples[i] < root.enterSamples[i - 1]) mono = false
        root.say("themed enter monotonic " + mono)
        root.say("themed presence after entry " + themed.presence)
        root.say("themed values settled " + themed.heightFactor + " " + themed.cardOpacity + " " + themed.cardScale + " " + themed.spacingTrim + " " + themed.clipping)
        // Now leave.
        themed.leave(function() { root.doneCalls++; root.say("themed done called, presence " + themed.presence) })
        root.say("themed leaving " + themed.leaving)
        themed.leave(function() { root.doneCalls += 100 })     // ignored: already leaving
        exitTimer.start()
      }
    }
  }

  property var exitSamples: []
  Timer {
    id: exitTimer
    interval: 20; repeat: true
    property int ticks: 0
    onTriggered: {
      ticks++
      root.exitSamples.push(themed.presence)
      if (ticks === 6) root.say("themed presence at ~120ms of exit " + themed.presence)
      if (ticks >= 28) {           // ~560 ms: well past the 300 ms exit
        stop()
        var mono = true
        for (var i = 1; i < root.exitSamples.length; i++) if (root.exitSamples[i] > root.exitSamples[i - 1]) mono = false
        root.say("themed exit monotonic " + mono)
        root.say("themed presence after exit " + themed.presence)
        root.say("done calls " + root.doneCalls)
        root.say("clipping when folded " + themed.clipping)
        // A fresh enter after a leave still works (a reused slot).
        Qt.quit()
      }
    }
  }
}
