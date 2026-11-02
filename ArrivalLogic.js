.pragma library

// annihilation: pure helpers for the arrival (components/ArrivalFlare.qml, ArrivalLayer.qml); tested by test/arrival-logic-test.js.
//
// One wave per toast leaves the card's centre. `front` is the radius, in px from there, it has reached; it crosses the card (revealing it
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

// How far the front runs beyond the card, px, for a screen this tall (judged at the real resolution). It sets the arrival's *timing* (how fast the
// front crosses the card); the ring no longer travels that far, it comes to rest at `holdReachFor`.
function ringReachFor(screenHeight) {
  return Math.max(180, Math.min(340, Number(screenHeight) * 0.26))
}

// How far from the card's outline the ring rests, px (it lingers there for the toast's life and undulates round it): the arrival's largest extent on screen.
function holdReachFor(screenHeight) {
  return Math.max(48, Math.min(84, Number(screenHeight) * 0.07))
}

// How far the front has to go from its origin (ix, iy, in the card's own pixels: its centre) to have crossed a w x h card, and a little more.
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

// The ring's size, 0 to 1, for a front at this radius: it grows with the wave and eases into its full size without ever stopping short (an exponential approach: it is
// 63% grown when the front is RING_EASE_PX out and 95% at three times that), so there is no wall where it reaches its resting size. The earlier version clamped the ring at a
// resting distance, which showed as a hard stop.
var RING_EASE_PX = 110

function ringScale(front) {
  return 1 - Math.exp(-Math.max(0, front) / RING_EASE_PX)
}

// The size on the way out, as the front retreats from `from`: the same curve, normalised so that it starts at the size the ring had (`s0`, 1 when it was resting).
function ringScaleExit(front, from, s0) {
  var k = ringScale(from)
  return k > 0 ? Math.min(1, s0 * ringScale(front) / k) : 0
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

// ---- The exit: the ring that has lingered round the card collapses onto it as the card dissolves into the light. `q` runs 0 to 1 over `exitDurationMs` (times the user's slowdown).
// The front starts from where the lingering ring rests (or from where the arrival's front is, if the toast leaves before the arrival has finished), slow at first and quicker
// as it falls in: the ring contracts onto the card, brightening, then the card dissolves from its far corner towards the icon and the spore goes out last. The slot folds
// shut once the dissolve is mostly done (EXIT_FOLD_AT), so the stack closes up behind it.
var EXIT_FOLD_AT = 0.8

function exitDurationMs() { return 1000 }

// Where the exit's front starts: the arrival's front now if it is still on the way, else just beyond the card by the hold reach (the ring's size then is `ringScaleExit`'s start).
function exitFrom(frontNow, cardReach, holdReach) {
  return Math.min(frontNow, cardReach + holdReach)
}

// The front's radius from the origin, from `from` at q = 0 to less than nothing at q = 1 (less 30 px so that nothing is left of the card, not even a soft edge round the icon).
function exitFront(q, from) {
  var c = clamp01(q)
  return from * (1 - Math.pow(c, 1.25)) - 30 * c
}

// How much of the flare's light there is: none while the front is still beyond the card (the settled rim is lit then), then up as it crosses
// the card, and out over the last of it so nothing lingers.
function exitFade(front, cardReach) {
  return (1 - settle(front, cardReach)) * clamp01(front / (0.35 * cardReach))
}
