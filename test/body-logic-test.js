// Tests BodyLogic.js (the oval body's pure helpers). Run: node test/body-logic-test.js
const fs = require("fs"), vm = require("vm"), path = require("path")
const ctx = {}; vm.createContext(ctx)
vm.runInContext(fs.readFileSync(path.join(__dirname, "..", "BodyLogic.js"), "utf8").replace(".pragma library", ""), ctx)
let pass = 0, fail = 0
function ok(name, cond, detail) { if (cond) pass++; else { fail++; console.log("FAIL", name, detail === undefined ? "" : detail) } }
function near(name, want, got, eps) { ok(name, Math.abs(want - got) <= eps, "want " + want + " got " + got) }

// distance to the shape
near("distance: on the outline along x it is 0", 0, ctx.ovalDistance(100, 0, 100, 50, 3), 1e-6)
near("distance: on the outline along y it is 0", 0, ctx.ovalDistance(0, 50, 100, 50, 3), 1e-6)
ok("distance: inside is negative, outside positive", ctx.ovalDistance(50, 10, 100, 50, 3) < 0 && ctx.ovalDistance(150, 0, 100, 50, 3) > 0)
near("distance: 20 px beyond the end is about 20 (the first-order distance is exact on an axis)", 20, ctx.ovalDistance(120, 0, 100, 50, 3), 0.5)
near("distance: with exponent 2 a circle's is the real one", 25, ctx.ovalDistance(125, 0, 100, 100, 2), 0.5)
// n = 3 is squarer than an ellipse: the corner (a * 0.8, b * 0.8) is outside an ellipse of those axes, inside a superellipse n=3
ok("shape: exponent 3 is fuller in the corners than an ellipse", ctx.ovalDistance(80, 40, 100, 50, 3) < ctx.ovalDistance(80, 40, 100, 50, 2))
{ let sym = true; for (const [x, y] of [[30, 20], [90, 10], [60, 40]]) { const d = ctx.ovalDistance(x, y, 100, 50, 3); for (const [sx, sy] of [[-1, 1], [1, -1], [-1, -1]]) if (Math.abs(ctx.ovalDistance(sx * x, sy * y, 100, 50, 3) - d) > 1e-9) sym = false }
  ok("shape: symmetric about both axes", sym) }
ok("distance: finite at the centre", isFinite(ctx.ovalDistance(0, 0, 100, 50, 3)))

// the feather
near("feather: solid 16 px inside the outline", 1, ctx.feather(-16), 1e-9)
near("feather: and deeper", 1, ctx.feather(-60), 1e-9)
near("feather: gone 10 px outside", 0, ctx.feather(10), 1e-9)
near("feather: and further out", 0, ctx.feather(80), 1e-9)
{ let mono = true, prev = 1; for (let s = -30; s <= 30; s += 0.5) { const v = ctx.feather(s); if (v > prev + 1e-12) mono = false; prev = v }
  ok("feather: only ever falls as you go out", mono) }
ok("feather: at the outline it is under a half (a soft edge: the body is mostly inside it)", ctx.feather(0) > 0.2 && ctx.feather(0) < 0.45, ctx.feather(0))
ok("feather: no step: a pixel's change is small (under 0.1)", (() => { let worst = 0; for (let s = -20; s < 14; s += 0.25) worst = Math.max(worst, Math.abs(ctx.feather(s) - ctx.feather(s + 0.25))); return worst < 0.1 })())

// the padding: the text's corners sit in the solid zone (a card of 380 x 80 design px and 404 x 92 once padded)
const before = ctx.textClearance(380, 80, 14, 12)
const after = ctx.textClearance(380 + 2 * ctx.PAD_X, 80 + 2 * ctx.PAD_Y, 14 + ctx.PAD_X, 12 + ctx.PAD_Y)
ok("padding: without it the text's corners are in the feather (about 7 px short of the solid zone)", before < -4 && before > -10, before)
ok("padding: with it they are inside the solid zone, by a few px", after > 3, after)
ok("padding: and it is a real change, over 10 px of room gained", after - before > 10, after - before)
ok("padding: a toast with one line (a card as low as 56 design px) is still clear of the feather", ctx.textClearance(404, 56 + 2 * ctx.PAD_Y, 14 + ctx.PAD_X, 9 + ctx.PAD_Y) > 0, ctx.textClearance(404, 56 + 2 * ctx.PAD_Y, 14 + ctx.PAD_X, 9 + ctx.PAD_Y))
ok("padding: and a tall one (three lines of body, 130 px)", ctx.textClearance(404, 130 + 2 * ctx.PAD_Y, 14 + ctx.PAD_X, 12 + ctx.PAD_Y) > 0, ctx.textClearance(404, 142, 26, 18))
{ // the oval does not stick out far: at most about 25 px past the card's side and 10 past its top and bottom
  const w = 404, h = 92, a = w / 2 * ctx.OVAL_KX, b = h / 2 * ctx.OVAL_KY
  ok("size: it reaches no more than 26 px past the card's ends and 11 past its top and bottom", a - w / 2 <= 26 && b - h / 2 <= 11, [a - w / 2, b - h / 2]) }
console.log(pass + " passed, " + fail + " failed"); process.exit(fail ? 1 : 0)
