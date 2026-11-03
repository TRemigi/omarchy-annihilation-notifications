.pragma library

// annihilation: the oval body of a toast (components/ToastBody.qml, shaders/toastbody.frag), tested by test/body-logic-test.js.
//
// The toast is not a card with a border any more: it is a soft-edged oval (a superellipse, exponent 3: clearly oval, with fuller ends than an ellipse so the
// text in the corners stays on it) concentric with the arrival's ring. Its size is the card's layout rectangle times (OVAL_KX, OVAL_KY); the card grows by
// PAD_X on each side and PAD_Y above and below (design px, times Style.space(1)) so the text sits well inside it. The edge is a feather, FEATHER_IN px inside the
// outline to FEATHER_OUT px outside it, not a line (26 px wide at first, then 44; live, over a near-black window, the toast was a lighter oval with an obvious silhouette, so the fade is long and mostly outside the outline: 22 solid, then 58 out, 80 px wide). Chosen from mock-ups on 2026-11-02
// (docs/design/blend/). The arrival's front is an oval of the toast's proportions while the toast has an oval body (`ovalAspect`, `ovalFrontReach`).
var OVAL_KX = 1.12
var OVAL_KY = 1.20
var OVAL_N = 3
var PAD_X = 12
var PAD_Y = 6
var FEATHER_IN = 22
var FEATHER_OUT = 58

// The distance, to first order, from the point (x, y) (from the centre) to the superellipse with semi-axes a and b and exponent n: negative inside.
function ovalDistance(x, y, a, b, n) {
  var ux = Math.max(Math.abs(x) / a, 1e-4), uy = Math.max(Math.abs(y) / b, 1e-4)
  var g = Math.pow(Math.pow(ux, n) + Math.pow(uy, n), 1 / n)
  var gx = Math.pow(g, 1 - n) * Math.pow(ux, n - 1) / a, gy = Math.pow(g, 1 - n) * Math.pow(uy, n - 1) / b
  return (g - 1) / Math.sqrt(gx * gx + gy * gy)
}

// The body's alpha (0 to 1, times the fill's own) at a distance from the outline: solid FEATHER_IN px inside, gone FEATHER_OUT px outside.
function feather(sd) {
  var t = Math.max(0, Math.min(1, (sd + FEATHER_IN) / (FEATHER_IN + FEATHER_OUT)))
  return 1 - t * t * (3 - 2 * t)
}

// How deep inside the outline the body is 98% solid, px.
function solidDepth() {
  var lo = -FEATHER_IN, hi = 0
  for (var i = 0; i < 40; i++) { var mid = (lo + hi) / 2; if (feather(mid) > 0.98) lo = mid; else hi = mid }
  return -(lo + hi) / 2
}

// How far inside the body's solid part (98% opaque) the text's corners sit, for a card whose themed layout is `w` x `h` design px: the content starts `inset` px in
// from the card's edge horizontally and `insetTop` from its top (12 + the border 2, and 10 + 2 for a toast with a body); positive means the text is fully on the body.
function textClearance(w, h, inset, insetTop) {
  var a = w / 2 * OVAL_KX, b = h / 2 * OVAL_KY
  var sd = ovalDistance(w / 2 - inset, h / 2 - insetTop, a, b, OVAL_N)
  return -sd - solidDepth()
}

// The arrival's front, while the toast has an oval body, is an oval of the body's proportions: its distance is stretched vertically by this much (the body's half-width over its half-height).
function ovalAspect(w, h) {
  return (w * OVAL_KX) / (h * OVAL_KY)
}

// How wide the arrival's reveal edge is, px (a card's is 26), and the most the stretched front's gradient is allowed to thin it vertically (REVEAL_GRADIENT_CAP, as in cardreveal.frag).
// A sharper edge showed as a hard oval, above all along the top and bottom, as the toast expanded.
var REVEAL_SOFT = 70
var REVEAL_GRADIENT_CAP = 3
// How far out the body's feather counts as visible (where it is under about 15% opaque it does not need revealing).
var FEATHER_VISIBLE = 40

// The radius (in that stretched distance, px from the centre) at which the front has crossed the visible body, for a `w` x `h` card: the furthest point of the body's outline pushed out
// FEATHER_VISIBLE px along the normal, in the stretched distance, plus the part of the soft edge that lies behind the front there (0.62 of it, stretched by the capped gradient).
function ovalFrontReach(w, h) {
  var a = w / 2 * OVAL_KX, b = h / 2 * OVAL_KY, k = a / b, worst = 0
  for (var i = 0; i < 360; i++) {
    var t = i * Math.PI / 180, c = Math.cos(t), s = Math.sin(t)
    var x = a * (c < 0 ? -1 : 1) * Math.pow(Math.abs(c), 2 / OVAL_N), y = b * (s < 0 ? -1 : 1) * Math.pow(Math.abs(s), 2 / OVAL_N)
    // the outline's normal, from the gradient of (|x/a|^n + |y/b|^n)
    var nx = Math.pow(Math.abs(x) / a, OVAL_N - 1) / a * (x < 0 ? -1 : 1), ny = Math.pow(Math.abs(y) / b, OVAL_N - 1) / b * (y < 0 ? -1 : 1)
    var nl = Math.sqrt(nx * nx + ny * ny) || 1
    var px = x + nx / nl * FEATHER_VISIBLE, py = y + ny / nl * FEATHER_VISIBLE
    var m = Math.sqrt(px * px + py * py * k * k)
    var g = Math.min(Math.max(Math.sqrt(px * px + py * py * k * k * k * k) / Math.max(m, 1e-3), 1), REVEAL_GRADIENT_CAP)
    worst = Math.max(worst, m + 0.6154 * REVEAL_SOFT * g)
  }
  return worst + 10
}
