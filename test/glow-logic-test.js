// Tests for GlowLogic.js: the theme's published glow state, the clock extrapolated from it, the rim width and the arrival's reach.
//   node test/glow-logic-test.js
const fs = require("fs"), path = require("path"), vm = require("vm")
const src = fs.readFileSync(path.join(__dirname, "..", "GlowLogic.js"), "utf8").replace(/^\.pragma.*$/m, "")
const ctx = {}; vm.createContext(ctx); vm.runInContext(src, ctx)
let pass = 0, fail = 0
const eq = (name, want, got) => { if (JSON.stringify(want) === JSON.stringify(got)) pass++; else { fail++; console.log("FAIL " + name + ": want " + JSON.stringify(want) + " got " + JSON.stringify(got)) } }
const near = (name, want, got, tol) => { if (Math.abs(want - got) <= tol) pass++; else { fail++; console.log("FAIL " + name + ": want " + want + " got " + got) } }
const good = { seed: 53, clock: 1200.5, at: 1700000000000, speed: 1.29, running: true, intensity: 0.44, depth: 0.21 }
const P = (o) => ctx.parseGlowState(JSON.stringify(o))

eq("a published state parses as it is", good, P(good))
eq("a missing file is null", null, ctx.parseGlowState(undefined))
eq("empty text (a file caught half written) is null", null, ctx.parseGlowState(""))
eq("garbage is null", null, ctx.parseGlowState("{not json"))
eq("a JSON array is null", null, ctx.parseGlowState("[1,2]"))
eq("a JSON number is null", null, ctx.parseGlowState("5"))
for (const k of ["seed", "clock", "at"]) {
  const o = Object.assign({}, good); delete o[k]
  eq("without " + k + " it is null", null, P(o))
  eq(k + " as a string is null", null, P(Object.assign({}, good, { [k]: "7" })))
  eq(k + " negative is null", null, P(Object.assign({}, good, { [k]: -1 })))
}
eq("a NaN clock (null in JSON) is null", null, P(Object.assign({}, good, { clock: null })))
eq("settings out of range fall back to the theme's defaults", { speed: 1.29, intensity: 0.44, depth: 0.21 },
   (({ speed, intensity, depth }) => ({ speed, intensity, depth }))(P(Object.assign({}, good, { speed: 99, intensity: 5, depth: 0 }))))
eq("settings in range are kept", { speed: 2, intensity: 0.7, depth: 0.5 },
   (({ speed, intensity, depth }) => ({ speed, intensity, depth }))(P(Object.assign({}, good, { speed: 2, intensity: 0.7, depth: 0.5 }))))
eq("running defaults to true when absent", true, P((({ running, ...o }) => o)(good)).running)
eq("running false is kept", false, P(Object.assign({}, good, { running: false })).running)

// the clock
near("at the moment it was published the clock is as published", 1200.5, ctx.clockAt(good, good.at), 1e-9)
near("ten seconds later it has advanced by ten times the speed", 1200.5 + 12.9, ctx.clockAt(good, good.at + 10000), 1e-9)
near("a different speed advances differently", 1200.5 + 20, ctx.clockAt(Object.assign({}, good, { speed: 2 }), good.at + 10000), 1e-9)
near("a clock that is not running stands still", 1200.5, ctx.clockAt(Object.assign({}, good, { running: false }), good.at + 10000), 1e-9)
near("a publication timestamp in the future does not run the clock backwards", 1200.5, ctx.clockAt(good, good.at - 5000), 1e-9)

// the windows' rim width
near("rim width at 1190 px tall (the author's screen)", 30.94, ctx.rimWidthFor(1190), 0.01)
eq("rim width has a floor of 16", 16, ctx.rimWidthFor(300))
eq("rim width has a ceiling of 44", 44, ctx.rimWidthFor(4000))

// the arrival's reach: from the icon to the farthest corner of the card, and 30 px more
near("a 380x78 card with its icon at (34, 39): the far corner is the top or bottom right", Math.sqrt(346 * 346 + 39 * 39) + 30, ctx.arrivalReach(34, 39, 380, 78), 1e-9)
near("an icon at the right edge reaches back across the card", Math.sqrt(300 * 300 + 20 * 20) + 30, ctx.arrivalReach(300, 20, 300, 40), 1e-9)
near("an icon in the middle needs only half the card", Math.hypot(50, 20) + 30, ctx.arrivalReach(50, 20, 100, 40), 1e-9)

// the toast's band depth
near("the default window depth gives the mock-up's toast depth", 0.13, ctx.toastDepth(0.21, 0.62, 0.2), 0.001)
near("a deeper window band is followed, up to the cap", 0.2, ctx.toastDepth(0.4, 0.62, 0.2), 1e-9)
near("the cap holds however deep the windows' is (the theme's slider goes to 2.5)", 0.2, ctx.toastDepth(2.5, 0.62, 0.2), 1e-9)
near("a very shallow band keeps a floor", 0.02, ctx.toastDepth(0.0, 0.62, 0.2), 1e-9)
near("junk falls back to the default", 0.13, ctx.toastDepth(undefined, 0.62, 0.2), 0.001)

console.log(pass + " passed, " + fail + " failed"); process.exit(fail ? 1 : 0)
