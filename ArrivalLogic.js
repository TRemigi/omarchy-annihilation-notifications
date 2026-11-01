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
