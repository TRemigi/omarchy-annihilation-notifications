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
near("feather: solid 22 px inside the outline", 1, ctx.feather(-22), 1e-9)
near("feather: and deeper", 1, ctx.feather(-60), 1e-9)
near("feather: gone 58 px outside", 0, ctx.feather(58), 1e-9)
near("feather: and further out", 0, ctx.feather(80), 1e-9)
{ let mono = true, prev = 1; for (let s = -30; s <= 30; s += 0.5) { const v = ctx.feather(s); if (v > prev + 1e-12) mono = false; prev = v }
  ok("feather: only ever falls as you go out", mono) }
ok("feather: at the outline it is still mostly opaque (0.8): the visible edge is well outside it, where the body is half there (17 px out), and it takes about 40 px more to fade", Math.abs(ctx.feather(0) - 0.815) < 0.01 && Math.abs(ctx.feather(18) - 0.5) < 0.03 && ctx.feather(58) === 0, [ctx.feather(0), ctx.feather(18)])
ok("feather: no step: a pixel's change is small (under 0.04: the steepest of an 80 px smoothstep is 0.019)", (() => { let worst = 0; for (let s = -30; s < 30; s += 0.25) worst = Math.max(worst, Math.abs(ctx.feather(s) - ctx.feather(s + 0.25)) * 4); return worst < 0.04 })())

// the padding: the text's corners sit in the solid zone (a card of 380 x 80 design px and 404 x 92 once padded)
const before = ctx.textClearance(380, 80, 14, 12)
const after = ctx.textClearance(380 + 2 * ctx.PAD_X, 80 + 2 * ctx.PAD_Y, 14 + ctx.PAD_X, 12 + ctx.PAD_Y)
ok("padding: without it the text's corners are in the feather (about 6 px short of the solid zone)", before < -3 && before > -12, before)
ok("padding: with it they are inside the solid zone (98% opaque), by a couple of px", after > 1, after)
ok("padding: and it is a real change, over 10 px of room gained", after - before > 10, after - before)
ok("padding: a toast with one line (a card as low as 56 design px) is still clear of the feather", ctx.textClearance(404, 56 + 2 * ctx.PAD_Y, 14 + ctx.PAD_X, 9 + ctx.PAD_Y) > 0, ctx.textClearance(404, 56 + 2 * ctx.PAD_Y, 14 + ctx.PAD_X, 9 + ctx.PAD_Y))
ok("padding: and a tall one (three lines of body, 130 px): at most 4 px short of the 98% zone, so still 95% opaque at the corners", ctx.textClearance(404, 130 + 2 * ctx.PAD_Y, 14 + ctx.PAD_X, 12 + ctx.PAD_Y) > -4, ctx.textClearance(404, 142, 26, 18))
{ // the oval does not stick out far: at most about 25 px past the card's side and 10 past its top and bottom
  const w = 404, h = 92, a = w / 2 * ctx.OVAL_KX, b = h / 2 * ctx.OVAL_KY
  ok("size: it reaches no more than 26 px past the card's ends and 11 past its top and bottom", a - w / 2 <= 26 && b - h / 2 <= 11, [a - w / 2, b - h / 2]) }
// the solid depth, and the oval front
near("solid depth: the body is 98% opaque about 15 px in", 15.4, ctx.solidDepth(), 0.4)
near("aspect: the front's vertical stretch is the body's half-width over half-height (404 x 92: 1.12 x 1.2)", (404 * 1.12) / (92 * 1.2), ctx.ovalAspect(404, 92), 1e-9)
{ const w = 404, h = 92, reach = ctx.ovalFrontReach(w, h), a = w / 2 * 1.12
  ok("front reach: well past the body's end in the stretched distance (its outline reaches 1.12 times the half-width at the corners), since the soft edge and the top and bottom feather have to be crossed too (400 to 700 for a standard card)", reach > a * 1.12 + 60 && reach < 700, reach)
  const soft0 = ctx.REVEAL_SOFT; ctx.REVEAL_SOFT = soft0 * 2; const wider = ctx.ovalFrontReach(w, h); ctx.REVEAL_SOFT = soft0
  ok("front reach: a softer reveal edge needs the front to go further", wider > reach + 20, [reach, wider])
  ok("front reach: and a taller toast (less stretched) needs less of it, a lower one more", ctx.ovalFrontReach(404, 130) < reach && ctx.ovalFrontReach(404, 60) > reach, [ctx.ovalFrontReach(404, 130), reach, ctx.ovalFrontReach(404, 60)])
  ok("reveal edge: 70 px, with the front's gradient capped at 3", ctx.REVEAL_SOFT === 70 && ctx.REVEAL_GRADIENT_CAP === 3) }
console.log(pass + " passed, " + fail + " failed"); process.exit(fail ? 1 : 0)
