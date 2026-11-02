.pragma library

// annihilation: pure helpers for the arrival (components/ArrivalFlare.qml, ArrivalLayer.qml); tested by test/arrival-logic-test.js.
//
// One wave per toast leaves the icon. `front` is the radius, in px from the icon, it has reached; it crosses the card (revealing it
// and flaring its edge) and goes on out into the screen as the ring. `p` runs 0 to 1 over the arrival's duration.

// How long an arrival lasts, ms: the theme's old ring's durations.
function durationFor(urgency) {
  return urgency === 0 ? 3200 : (urgency === 2 ? 6000 : 4200)
}

// How strong an arrival is: critical more, low less, Omarchy's own toasts (screenshots and recordings, which the user has just asked for)
// and a burst fainter.
function amplitudeFor(app, urgency, sinceLastMs) {
  var base = urgency === 0 ? 0.6 : (urgency === 2 ? 1.3 : 1.0)
  if (app === "omarchy-action") base *= 0.7
  if (sinceLastMs < 400) base *= 0.6
  return base
}

// How far the ring travels beyond the card, px, for a screen this tall (judged at the real resolution).
function ringReachFor(screenHeight) {
  return Math.max(180, Math.min(340, Number(screenHeight) * 0.26))
}

// How far the front has to go from the icon (ix, iy, in the card's own pixels) to have crossed a w x h card, and a little more.
function cardReach(ix, iy, w, h) {
  var dx = Math.max(ix, w - ix), dy = Math.max(iy, h - iy)
  return Math.sqrt(dx * dx + dy * dy) + 30
}

function clamp01(x) { return Math.max(0, Math.min(1, x)) }

// How far along the wave is: quick off the icon, slowing.
function travel(p) {
  var q = 1 - clamp01(p)
  return 1 - q * q * q
}

function frontAt(p, cardReach, ringReach) {
  return (cardReach + ringReach) * travel(p)
}

function progressOf(startMs, nowMs, durMs) {
  return durMs > 0 ? clamp01((nowMs - startMs) / durMs) : 1
}

// 0 while the front is still crossing the card, 1 once it has crossed it (the flare is over and the look's own rim has taken over),
// smooth in between: the hand-over from the arrival's edge light to the settled rim.
function settle(front, cardReach) {
  var t = clamp01((front / cardReach - 0.7) / 0.4)
  return t * t * (3 - 2 * t)
}

// A toast is fresh enough to arrive (rather than be a restored one after a shell restart) if it is under 3 s old.
function isFresh(timestampMs, nowMs) {
  return nowMs - Number(timestampMs) < 3000
}

// ---- The exit: the arrival played backwards, faster. `q` runs 0 to 1 over `exitDurationMs` (times the user's slowdown).
// The wave is the arrival's from a progress `exitStart` back to 0, chosen so that at q = 0 the front is just beyond the card (15% past its reach), whatever the
// screen: a ring a little beyond the card contracts onto it, brightening, as the front retreats across the card to the icon, so the card dissolves from its far
// corner into the light and the spore at the icon goes out last. The slot folds shut once the dissolve is mostly done (EXIT_FOLD_AT), so the stack closes up behind it.
var EXIT_FOLD_AT = 0.8

function exitDurationMs() { return 1000 }

// The arrival's own progress at which the front is 15% beyond the card (capped, for a ring reach so small that the front would never get there).
function exitStart(cardReach, ringReach) {
  var r = Math.min(1.15 * cardReach / (cardReach + ringReach), 0.97)
  return 1 - Math.pow(1 - r, 1 / 3)
}

// The arrival's progress that the exit is at (`p0` at the start, 0 at the end).
function exitProgress(q, p0) {
  return p0 * (1 - clamp01(q))
}

// The front's radius from the icon: the arrival's at that progress, less up to 30 px so that at the end nothing is left of the card, not even a
// soft edge of it round the icon.
function exitFront(q, cardReach, ringReach) {
  return frontAt(exitProgress(q, exitStart(cardReach, ringReach)), cardReach, ringReach) - 30 * clamp01(q)
}

// How much of the flare's light there is: none while the front is still beyond the card (the settled rim is lit then), then up as it crosses
// the card, and out over the last of it so nothing lingers.
function exitFade(front, cardReach) {
  return (1 - settle(front, cardReach)) * clamp01(front / (0.35 * cardReach))
}
