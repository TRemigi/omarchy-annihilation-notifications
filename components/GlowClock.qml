// annihilation: the window glow's clock and seed, so a toast is lit by the same light as the windows around it.
//
// The glow's colour is a field over the whole screen that drifts with a shader clock and starts from a random seed, both
// kept inside the theme's plugin. The theme publishes them (see GlowLogic.parseGlowState) and this reads them, watching the
// file; between writes the clock is extrapolated at the published speed. Without the file (an older theme, or none) the
// toast is lit on this item's own clock and seed, with the theme's default settings: the same kind of light, just not
// in step with the windows.
import QtQuick
import Quickshell
import Quickshell.Io
import "../GlowLogic.js" as GlowLogic

Item {
  id: root

  property string path: ""
  // true once the theme's state has been read
  property bool shared: false
  property real seed: Math.random() * 100
  property real intensity: 0.44
  property real depth: 0.21
  // what was last published, or our own start (a plain value: nothing here is re-evaluated)
  property var published: ({ clock: Math.random() * 3600, at: Date.now(), speed: 1.29, running: true })

  function clockNow() { return GlowLogic.clockAt(published, Date.now()) }

  FileView {
    path: root.path
    watchChanges: true
    printErrors: false
    onLoaded: {
      var s = GlowLogic.parseGlowState(text())
      if (!s) return                // a file caught half written: keep what we had
      root.published = s
      root.seed = s.seed
      root.intensity = s.intensity
      root.depth = s.depth
      root.shared = true
    }
    onFileChanged: reload()
    onLoadFailed: root.shared = false
  }
}
