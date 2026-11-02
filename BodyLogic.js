.pragma library

// annihilation: the oval body of a toast (components/ToastBody.qml, shaders/toastbody.frag), tested by test/body-logic-test.js.
//
// The toast is not a card with a border any more: it is a soft-edged oval (a superellipse, exponent 3: clearly oval, with fuller ends than an ellipse so the
// text in the corners stays on it) concentric with the arrival's ring. Its size is the card's layout rectangle times (OVAL_KX, OVAL_KY); the card grows by
// PAD_X on each side and PAD_Y above and below (design px, times Style.space(1)) so the text sits well inside it. The edge is a feather, FEATHER_IN px inside the
// outline to FEATHER_OUT px outside it, not a line. Chosen from mock-ups on 2026-11-02 (docs/design/blend/).
var OVAL_KX = 1.12
var OVAL_KY = 1.20
var OVAL_N = 3
var PAD_X = 12
var PAD_Y = 6
var FEATHER_IN = 16
var FEATHER_OUT = 10

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

// How far inside the body's solid part the text's corners sit, for a card whose themed layout is `w` x `h` design px: the content starts `inset` px in
// from the card's edge horizontally and `insetTop` from its top (12 + the border 2, and 10 + 2 for a toast with a body); positive means inside the
// solid zone (FEATHER_IN px from the outline), so the text is fully on the body.
function textClearance(w, h, inset, insetTop) {
  var a = w / 2 * OVAL_KX, b = h / 2 * OVAL_KY
  var sd = ovalDistance(w / 2 - inset, h / 2 - insetTop, a, b, OVAL_N)
  return -sd - FEATHER_IN
}
