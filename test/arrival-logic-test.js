// Tests for ArrivalLogic.js: durations, strengths, the front's travel and the hand-over from the arrival's edge light to the settled rim.
//   node test/arrival-logic-test.js
const fs = require("fs"), path = require("path"), vm = require("vm")
const src = fs.readFileSync(path.join(__dirname, "..", "ArrivalLogic.js"), "utf8").replace(/^\.pragma.*$/m, "")
const ctx = {}; vm.createContext(ctx); vm.runInContext(src, ctx)
let pass = 0, fail = 0
const eq = (name, want, got) => { if (JSON.stringify(want) === JSON.stringify(got)) pass++; else { fail++; console.log("FAIL " + name + ": want " + JSON.stringify(want) + " got " + JSON.stringify(got)) } }
const near = (name, want, got, tol) => { if (Math.abs(want - got) <= tol) pass++; else { fail++; console.log("FAIL " + name + ": want " + want + " got " + got) } }
const yes = (name, ok, detail) => { if (ok) pass++; else { fail++; console.log("FAIL " + name + (detail !== undefined ? ": " + JSON.stringify(detail) : "")) } }

eq("durations: low, normal, critical", [3200, 4200, 6000], [0, 1, 2].map(ctx.durationFor))
eq("amplitude: normal is 1", 1, ctx.amplitudeFor("Signal", 1, 1e9))
eq("amplitude: critical is stronger", 1.3, ctx.amplitudeFor("Signal", 2, 1e9))
eq("amplitude: low is fainter", 0.6, ctx.amplitudeFor("Signal", 0, 1e9))
near("amplitude: Omarchy's own toasts are fainter", 0.7, ctx.amplitudeFor("omarchy-action", 1, 1e9), 1e-9)
near("amplitude: a burst (under 400 ms after the last) is fainter", 0.6, ctx.amplitudeFor("Signal", 1, 399), 1e-9)
eq("amplitude: 400 ms after is not a burst", 1, ctx.amplitudeFor("Signal", 1, 400))
near("amplitude: the two reductions stack", 0.42, ctx.amplitudeFor("omarchy-action", 1, 10), 1e-9)

near("ring reach at 1190 px tall (the author's screen)", 309.4, ctx.ringReachFor(1190), 0.01)
eq("ring reach has a floor of 180", 180, ctx.ringReachFor(300))
eq("ring reach has a ceiling of 340", 340, ctx.ringReachFor(4000))

near("card reach: a 380x78 card with its icon at (34, 39) must be crossed to the far right corner, and 30 more", Math.hypot(346, 39) + 30, ctx.cardReach(34, 39, 380, 78), 1e-9)
near("card reach: an icon at the right edge reaches back across the card", Math.hypot(300, 20) + 30, ctx.cardReach(300, 20, 300, 40), 1e-9)

eq("travel starts at 0", 0, ctx.travel(0))
eq("and ends at 1", 1, ctx.travel(1))
eq("it is clamped below 0 and above 1", [0, 1], [ctx.travel(-1), ctx.travel(2)])
yes("it is quick off the icon and slows (the first tenth covers more than the last tenth)", ctx.travel(0.1) - ctx.travel(0) > 5 * (ctx.travel(1) - ctx.travel(0.9)))
let mono = true; for (let i = 1; i <= 100; i++) if (ctx.travel(i / 100) < ctx.travel((i - 1) / 100)) mono = false
yes("and never goes back", mono)
const rc = ctx.cardReach(34, 39, 380, 78), rr = 309.4
near("the front is the card's reach plus the ring's by the end", rc + rr, ctx.frontAt(1, rc, rr), 1e-9)
eq("and at the start it is at the icon", 0, ctx.frontAt(0, rc, rr))
const crossP = [...Array(101).keys()].map(i => i / 100).find(p => ctx.frontAt(p, rc, rr) >= rc)
yes("the front has crossed the card in about a fifth of the arrival (1 s of 4.2)", crossP > 0.15 && crossP < 0.3, crossP)

eq("progress: before the start is 0", 0, ctx.progressOf(1000, 500, 4200))
near("progress: halfway", 0.5, ctx.progressOf(1000, 3100, 4200), 1e-9)
eq("progress: after the end is 1", 1, ctx.progressOf(1000, 9000, 4200))
eq("progress: a zero duration is already over", 1, ctx.progressOf(1000, 1000, 0))

eq("settle: 0 while the front is still crossing the card", 0, ctx.settle(0.5 * rc, rc))
eq("settle: 1 once it has crossed", 1, ctx.settle(1.2 * rc, rc))
const mid = ctx.settle(0.9 * rc, rc); yes("settle: in between, smooth", mid > 0.2 && mid < 0.9, mid)
let m2 = true; for (let i = 1; i <= 100; i++) if (ctx.settle(i / 50 * rc, rc) < ctx.settle((i - 1) / 50 * rc, rc)) m2 = false
yes("settle: only rises", m2)

eq("fresh: a toast from a second ago arrives", true, ctx.isFresh(9000, 10000))
eq("fresh: one from a minute ago (restored after a shell restart) does not", false, ctx.isFresh(10000 - 60000, 10000))
eq("fresh: the limit is 3 s", [true, false], [ctx.isFresh(7001, 10000), ctx.isFresh(7000, 10000)])

// the ring's size: it eases into its full size, no wall
eq("ring size: nothing at the start, and for a negative front", [0, 0], [ctx.ringScale(0), ctx.ringScale(-50)])
near("ring size: 63% grown at one ease length (110 px)", 1 - Math.exp(-1), ctx.ringScale(110), 1e-9)
yes("ring size: 95% at three ease lengths", ctx.ringScale(330) > 0.95 && ctx.ringScale(330) < 0.96)
yes("ring size: never over 1, and nearly 1 when the wave has gone right out (the arrival's full run)", ctx.ringScale(1e6) <= 1 && ctx.ringScale(530) > 0.99)
{ let up = true, slow = true; let prev = ctx.ringScale(0), prevStep = 1
  for (let f = 5; f <= 600; f += 5) { const v = ctx.ringScale(f); if (v < prev) up = false; if (v - prev > prevStep + 1e-12) slow = false; prevStep = v - prev; prev = v }
  yes("ring size: only grows, and each step is smaller than the one before (it eases in, with no stop)", up && slow) }
for (const [from, s0] of [[305, 0.99], [180, 0.6], [305, 1]]) {
  near("ring size on the way out: starts at the size it had (from " + from + ")", Math.min(1, s0), ctx.ringScaleExit(from, from, s0), 1e-9)
  eq("ring size on the way out: nothing at the end", 0, ctx.ringScaleExit(0, from, s0))
  yes("ring size on the way out: only shrinks as the front falls, never over 1 (from " + from + ")", [from, from * 0.8, from * 0.5, from * 0.2, 0].every((f, i, a) => i === 0 || ctx.ringScaleExit(f, from, s0) <= ctx.ringScaleExit(a[i - 1], from, s0)) && ctx.ringScaleExit(from, from, 1) <= 1)
}

// the exit: the lingering ring collapses onto the card
eq("exit: the fold is mostly through the dissolve", 0.8, ctx.EXIT_FOLD_AT)
eq("exit: it lasts a second", 1000, ctx.exitDurationMs())
eq("hold reach: 7% of the screen's height, between 48 and 84 px", [48, 75.6, 84], [ctx.holdReachFor(300), Math.round(ctx.holdReachFor(1080) * 10) / 10, ctx.holdReachFor(4000)])
yes("hold reach: much smaller than the front's run (it is the arrival's largest extent now)", ctx.holdReachFor(1190) < 0.3 * ctx.ringReachFor(1190))
for (const hr of [48, 75.6, 84]) {
  const from = ctx.exitFrom(1e6, rc, hr)
  near("exit: from rest the front starts just beyond the card by the hold reach (" + hr + ")", rc + hr, from, 1e-9)
  near("exit: a toast leaving mid-arrival starts where the front is", 120, ctx.exitFrom(120, rc, hr), 1e-9)
  near("exit: q=0 puts the front at its start", from, ctx.exitFront(0, from), 1e-9)
  near("exit: q=1 leaves less than nothing of the card (the front is at -30)", -30, ctx.exitFront(1, from), 1e-9)
  let down = true; for (let i = 1; i <= 100; i++) if (ctx.exitFront(i / 100, from) > ctx.exitFront((i - 1) / 100, from)) down = false
  yes("exit: the front only ever retreats (" + hr + ")", down)
  yes("exit: it is slow to start and quick to finish (the last tenth covers more than the first tenth) (" + hr + ")", ctx.exitFront(0.9, from) - ctx.exitFront(1, from) > ctx.exitFront(0, from) - ctx.exitFront(0.1, from))
  yes("exit: the card starts to dissolve (the front crosses its edge) within the first third (" + hr + ")", ctx.exitFront(0.33, from) < rc + 30)
  eq("exit: q is clamped", [from, -30], [ctx.exitFront(-1, from), ctx.exitFront(2, from)])
}
eq("exit: no flare while the front is still beyond the card", 0, ctx.exitFade(1.15 * rc, rc))
yes("exit: the flare comes up as the front crosses the card", ctx.exitFade(0.8 * rc, rc) > 0.5, ctx.exitFade(0.8 * rc, rc))
eq("exit: and is out at the end (nothing lingers)", 0, ctx.exitFade(0, rc))
yes("exit: and out over the last of it", ctx.exitFade(0.1 * rc, rc) < ctx.exitFade(0.35 * rc, rc))

console.log(pass + " passed, " + fail + " failed"); process.exit(fail ? 1 : 0)
