# The toast's look: directions

Mock-ups, not the implementation (the real card is QML plus a shader). They are drawn over a dark window with
the theme's arrival ring behind them (the real shader, progress 0.22), at 2x, with a normal toast and a critical
one. Regenerate with `FONTS=<dir with Jost.ttf and Cinzel.ttf> python3 mock-toasts.py backdrop.png out/` (numpy
and pillow). `overview.png` is all four at once.

| File | What it is |
|------|-----------|
| `0-current.png` | Omarchy's card with the theme's tokens: a dark box, a 2 px gradient outline, plain text. The baseline. |
| `A-refraction.png` | The card as a pane of glass the Shimmer passes through. |
| `B-field-note.png` | The card as a page from the expedition journal. |
| `C-growth.png` | The card as something growing. |

## A. Refraction
An iridescent rim (a narrow slice of the spectrum, drifting along the edge and brightest where the light comes from)
with a soft prism spill just inside it and a faint halo outside, the same language as the window glow. The title
carries a faint glow, like the screensaver crawl. A small caption row (app, time) above it. The icon becomes a
ring with a spore at its centre. The countdown is a line of light along the bottom edge that drains, ending in a
bright spark. Critical toasts use the amber-to-pink slice, low ones moss. *Strength:* it continues the wave behind it,
so the toast reads as the wave condensing into an object. *Risk:* easily too neon; the mock is more saturated than
the theme's "subdued" rule wants, and the rim needs a shader (cheap, but it is real GPU work per card).

## B. Field note
No glow. A warm, slightly lighter page with paper grain, a double rule, amber corner ticks, a small-caps header in
Cinzel (app name, with an amber spore for unread, and the time), then the title and body in Jost. The countdown is a
row of ticks like a ruler. *Strength:* the most distinctive typography, cheap to render (no shader), and a strong tie to
the film's journals and the theme's popup. *Risk:* it fights the wave rather than continuing it (a flat page over a
glowing background), and it is the least "psychedelic". (In the mock the tick row collides with the body; a real card
would be taller.)

## C. Growth
An outline that is not quite straight, a ragged strip of lichen down the left edge, veins reaching out from the
corners, spores drifting off the top edge, and a countdown that is a wavering vein. *Strength:* the most "nature".
*Risk:* the hardest to make look intentional rather than crude; the wavy outline and ragged strip read as glitches at
this size. The spores are the one part that works at once.

## As built (slice 2)
`shader-settled.png` and `shader-ignite.png` are the real `shaders/toastrim.frag`, run on Mesa's software GL and composited
over the same backdrop (no text; `test/rim-preview.py` makes them): the settled rim and icon ring, and the brighter
gleam it starts from when the toast arrives and cools from over about a second. The rim is the toned-down version of
mock A (vividness 0.75).

`shader-countdown.png` adds the countdown (slice 3): a line of light along the bottom edge that drains, ending in a
spark, here with 62% of the toast's life left (`shader-countdown-full.png`: a fresh toast, the line from border to border); the critical toast below it has none, because it never expires.

`spores-exit.png` is the exit burst as built (slice 4): a toast folding away over the backdrop, and its spores at 0, 120,
300, 600, 950 and 1400 ms (`test/spores-preview.py`). They drift **left**, not up as in mock-up C, because a toast in
the top-right corner of the screen has no room above it, and drifting down would cross the toast below.

`shader-ambient.png` is the faint drift (slice 4b) at two moments: a few small spores leaving a card's left edge and drifting
away over several seconds, deliberately barely there (`test/rim-preview.py ... 1 <time>`).

## As built (slice 6, the Growth experiment, on `p2/growth`)
`growth-settled.png` and `growth-arriving.png` (the second 0.4 of the way through the arrival, rim still bright) are the real
`shaders/toastgrowth.frag`, rendered like the others (`SHADER=toastgrowth python3 test/rim-preview.py ...`). It is a second
shader behind `look=growth`, so the live comparison with the blend is one line in the conf file. What changed from the
mock-up C, whose wavy outline and ragged strip read as glitches:
- **The outline stays straight and is alive instead**: thickness and colour vary slowly along its length (colonies of moss
  and teal), its edge moves under a pixel, and a slow pulse of sap travels round it.
- **Lichen is a scatter of tiny dots**, jittered so it is not a grid, clustered in patches on the left edge inside the card,
  thinning inward and kept clear of the icon; not a ragged strip. (A denser, deeper version, creeping along the top and bottom
  too, was tried after the first live test and was too much and in the way: the user had meant the roots, below, not the lichen.)
- **Roots**: fine curves with two side branches, along the left edge (about one per 18 px of the card's height, 67 to 96 px long) and the
  bottom edge (about one per 20 px of its width, 53 to 82 px; under a toast with another below they pass behind it, and under the
  last toast the screen is free). Those near the top lean down and those near the bottom lean up, so they stay in the card's band.
  **Growth runs over the toast's whole life**: each root starts at its own moment in the first 8% of it and finishes at its own
  between 97% and 99.5%, so the last is done just before the countdown completes. Its shape is three parts exponential slowdown
  (1 - exp(-5t), normalised: the speed falls by the same ratio in each stretch of time, a hard but natural slowdown) and one part a
  gentle ease-out (1 - (1-t)^1.5: it keeps going and stops exactly at the end), with a short ease-in over the first 15% of its window.
  Measured on the compiled shader for an 8 s toast, the left roots' reach is 0% after 0.5 s (staggered starts), 28% after 1 s,
  54% after 2, 72% after 3, 84% after 4, 91% after 5, 96% after 6 and 99% after 7. `growth-stages.png`: 6%, 12.5%, 25%, 50%, 75%
  and 97% of the life. Earlier versions, each judged wrong live: one root per corner in 1.5 s; ease-out of power 2 (not dramatic);
  power 3.5 (fine, but it then froze); a burst of 74% in a second plus a creep (snapped into place, and done by 80 to 94% of the
  life); 50% ease-out plus 50% linear (popped at the start, too linear); a cubic Bezier (eased in well, "still pretty linear": its
  speed fell only fivefold from 1 s to 5 s); a pure exponential (liked: fast, hard slowdown, but it moved by under 2 px/s after four
  seconds, so it "mostly stopped growing well before the countdown finished"; the 25% gentle part fixed that at the cost of a body a
  few points slower: 28% after a second instead of 35%).
  **"Still finishes, or appears to finish, well before the countdown"** (from a screen recording, 2026-10-31): the trunk curve was
  right, but measuring the recording and the shader's output showed the roots' visible ink was 96% complete after 3 s of an 8 s toast
  and 99% after 5 s, because the branches near a root's base fill in early and the trunk's last tenth is only a few pixels. Slowing
  the trunk further would have lost the curve the user liked, so **each root now has four side shoots** (at trunk steps 4, 7, 10 and
  13, alternating sides) **that sprout on their own, later schedule**: they start at about 10%, 30%, 50% and 70% of the life (each
  jittered), once the trunk has reached their step, grow with a gentler ease-out, and are full at 97 to 99.5%. So something is always
  still sprouting or extending to the end of the countdown. Net root ink (excluding the rim's constant halo), as a share of the final,
  after 1, 2, 3, 4, 5, 6, 7 s of an 8 s toast: was 21, 77, 92, 96, 98, 99, 99; now 17, 55, 68, 79, 88, 93, 98. The roots end up
  branchier (four shoots instead of two).
  **Tuning the pace against the recording** (2026-10-31, "the apparent amount of activity lessens too soon; slow the fast stage a bit and
  push the slowdown later"): `test/growth-activity.py` measures, on the compiled shader, the same thing as the recording (high-pass ink
  outside the card, pixels more than 22/255 above their 5 px blur, as a share of the final, per second of life; it agrees with the
  recording to within about five points). The recording gained 43, 19, 12, 9, 8, 6 and 3 points per second: activity halved from the
  first second to the second. A search over the trunk curve and the shoot schedule (the trunk barely moves the ink; the shoots do)
  settled on a trunk of 65% exponential (rate 3.5) and 35% gentle ease-out, with shoots starting from 16% of the life in steps of 16% and
  a more linear ease (power 1.5): gains of 34, 25, 13, 11, 8, 6 and 2 points per second (cumulative 34, 59, 72, 83, 91, 97 and 100).
  Fainter veins grow across the card from its right corners.
  **Roots as lit 3D tubes** (after 0.5.0, `growth-roots-3d.png`): each segment is a round tube with a soft edge, a little thicker than the
  first lines (radius about 0.8 to 0.9 px at the base, tapering to about half), shaded as a cylinder lit from the top right (the
  direction of the card's own light): a diffuse term, a soft specular highlight and a darker side away from the light, and a soft
  shadow they cast down and to the left (a little alpha, the only part that darkens; the roots inside the card cast none).
- **No countdown line** (removed after 0.5.0, at the user's request): the roots grow over the toast's whole life and are the timer.
  (Until then the countdown was the card's own bottom border, lit: drawn from the same distance field and sway as the outline so it lay
  exactly on it and read as one line, thicker and brighter where there was time left, ending in a bud. The blend look keeps its own
  countdown line.)
- Palettes: moss and teal; ember for critical; dark moss for low. Everything is added light, as in the blend, and the spores
  (exit burst and faint drift) are shared.

## Decision (2026-10-30)
The user chose the blend below. **Follow-up to try later: the full C "Growth" direction** (organic outline,
lichen strip, veins, wavering countdown), on its own branch, judged against the blend.

## Recommendation
Take **A as the base**, tuned down in saturation and with the rim ignited bright at arrival and cooling over about a
second (light becoming matter, tying the ring to the card), **B's typographic header** (the Cinzel small-caps app
name and the quiet time) because it is the cheapest big step away from "a normal toast", and **C's spores** for
the exit and as a faint drift above a card (already planned as slice 3). Leave out the wavy outline and the ragged strip.
