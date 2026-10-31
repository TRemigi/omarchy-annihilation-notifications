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
- **Roots**: fine curves with two side branches, along the left edge (about one per 18 px of the card's height) and the bottom edge
  (about one per 20 px of its width), 1.0 to 1.5 times the first length on the left (up to about 65 px) and a little shorter below,
  where the gap to the toast below is small (they pass behind it; under the last toast the screen is free). Those near the top
  lean down and those near the bottom lean up, so they stay in the card's band. **They grow over the toast's whole life**, not
  at arrival: each starts at its own moment (in the first 14% of the life) and finishes at its own (between 80% and 94% of it,
  so the last is done shortly before the countdown completes). It bursts out and slows hard (an ease-out of power 3.5: 30% grown
  a tenth of the way through its time, 64% a quarter of the way, 91% half way, then it creeps; an earlier power of 2 was not
  dramatic enough). `growth-stages.png`: 2%, 5%, 10%, 20%, 40% and 80% of the life. Fainter ones grow across the card from its right corners. The first version had one per
  corner and grew in 1.5 s.
- **The countdown is the bottom border itself, lit**: drawn from the same distance field and sway as the outline, so it lies
  exactly on it and the two read as one line (the first version ran 3 px above the border, which the user saw as two lines).
  Where there is time left the border is brighter and thicker, its thickness undulating along it like a vein; the part that has run
  out is the plain border. It retreats from the right and ends in a bud.
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
