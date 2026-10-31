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
spark, here with 62% of the toast's life left (`shader-countdown-full.png`: a fresh toast, the line the card's whole
length); the critical toast below it has none, because it never expires.

## Decision (2026-10-30)
The user chose the blend below. **Follow-up to try later: the full C "Growth" direction** (organic outline,
lichen strip, veins, wavering countdown), on its own branch, judged against the blend.

## Recommendation
Take **A as the base**, tuned down in saturation and with the rim ignited bright at arrival and cooling over about a
second (light becoming matter, tying the ring to the card), **B's typographic header** (the Cinzel small-caps app
name and the quiet time) because it is the cheapest big step away from "a normal toast", and **C's spores** for
the exit and as a faint drift above a card (already planned as slice 3). Leave out the wavy outline and the ragged strip.
