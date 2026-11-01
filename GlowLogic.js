.pragma library

// annihilation: pure helpers for the glow look (components/GlowClock.qml, GlowRim.qml); tested by test/glow-logic-test.js.

// The theme publishes its window glow's clock and settings in ~/.local/state/annihilation-theme/glow.json
// (extras/plugin/annihilation.shimmer/Service.qml): {"seed", "clock" (the shader clock at `at`), "at" (epoch ms),
// "speed" (clock seconds per second), "running", "intensity", "depth"}. Returns the validated fields, or null when the text
// is not that (a missing or garbled file means "light the toast on our own clock").
function parseGlowState(raw) {
  var o
  try { o = JSON.parse(String(raw || "")) } catch (e) { return null }
  if (!o || typeof o !== "object") return null
  function num(v, lo, hi, fallback) {
    return typeof v === "number" && isFinite(v) && v >= lo && v <= hi ? v : fallback
  }
  var clock = num(o.clock, 0, 1e9, -1)
  var at = num(o.at, 1, 1e14, -1)
  var seed = num(o.seed, 0, 1e4, -1)
  if (clock < 0 || at < 0 || seed < 0) return null
  return {
    seed: seed,
    clock: clock,
    at: at,
    speed: num(o.speed, 0.1, 4, 1.29),
    running: o.running !== false,
    intensity: num(o.intensity, 0, 1, 0.44),
    depth: num(o.depth, 0.02, 2.5, 0.21)
  }
}

// The glow's clock now, given what was published: it advances at `speed` while the glow runs, and stands still when not.
function clockAt(state, nowMs) {
  if (!state.running) return state.clock
  return state.clock + Math.max(0, nowMs - state.at) / 1000 * state.speed
}

// The windows' rim width in px for a screen this tall (WindowGlow.qml: 0.026 of the height, 16 to 44).
function rimWidthFor(screenHeight) {
  return Math.max(16, Math.min(44, Number(screenHeight) * 0.026))
}

// How far a front of light leaving (ix, iy) has to travel to have crossed a w x h card, and a little more.
function arrivalReach(ix, iy, w, h) {
  var dx = Math.max(ix, w - ix), dy = Math.max(iy, h - iy)
  return Math.sqrt(dx * dx + dy * dy) + 30
}
