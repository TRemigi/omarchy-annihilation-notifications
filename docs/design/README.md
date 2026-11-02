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
  **Realistic texture and shape, still glowing** (the last step): "more realistic" was tried first as solid bark-coloured roots, drawn opaque over what is behind them; the user liked the
  texture and shape but said they "should still be the glow", so the roots are light again (the toast's own colour, added, like the rim), keeping what made them
  realistic: a **rough edge** (the radius varies by noise along the length), **lengthwise grain** and **mottling** (noise that also tilts the surface's normal, so
  the glow varies along and across them), **knots and necks** (a radius modulation that is continuous from step to step) and a thickening where a shoot leaves, a
  **less regular path** (heading jitter, and a pull towards hanging straight down, so roots droop), shoots at **acute angles** (about 35 degrees, not 50), and a
  more matte, broader highlight. (Lesson: a request for realism is not a request to change the look's identity; ask which of material and form is meant if it
  is not clear, or keep the identity and change the form first.)
  **Roots as lit 3D tubes** (after 0.5.0, `growth-roots-3d.png`): each segment is a round tube with a soft edge, five times as thick as the
  first lines at the base (asked for in steps: a little thicker, "at least twice as thick", "three times thicker now", then, from a screenshot of
  the real shell, "a little thinner than that" and "more tapered"; radius about 4.1 to 4.6 px at the base on the left and 3.9 to 4.3 below,
  tapering along a concave curve, `taper()`: 100%, 65%, 46%, 31%, 19% and 10% at 0, 20, 40, 60, 80 and 100% of the way, so they thin quickly
  and end in fine points; the side shoots start at about half the trunk's radius instead of 70%, so they are slender, not stubby; the faint veins inside the card stay thin, so they do
  not run over the text), and thinned out to make room (about one root per 24 px of the card's height on the left, one per 40 px of
  its width below). Two rendering lessons at this size: shading each segment from its own axis shows the joins (and with ties settled by
  coverage, as stacked beads), so the shading comes from the direction to the nearest point on the spine and, where two pieces overlap, from the
  piece the pixel is nearer the middle of, with the silhouettes joined, shaded as a cylinder lit from the top right (the
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

## Rethink: toasts as part of the glow (mock-ups, 2026-10-31, `docs/design/glow/`)
The toasts were still cards sitting on top of the glow: their own rim, their own palette, and an arrival ring that started from a
fixed box in the corner instead of from the card. These mock-ups light the toast with **the window glow's own light** instead.
`glow/glow-mock.frag` copies the colour field (`fanField`, `lightSpectrum`, `glints`) and the band's profile unchanged from the theme's
`windowglow.frag`, so a toast and the window beside it are lit by one light; the windows in the scene are lit by the theme's real shader.
Seed 53, time 40, the author's glow settings (intensity 0.44; the toast band is depth 0.13 against the windows' 0.21, because a 78 px
card with the windows' band reads as a bevelled frame). Regenerate: `python3 docs/design/glow/glow-mock.py OUTDIR [seed] [time]`
(`SCAN=3,8,13` makes a contact sheet of seeds; `TDEPTH=` sets the toast band).

| File | What it shows |
|------|---------------|
| `glow-0-today.png` | Today's card (the blend look) in the same scene, for comparison. |
| `glow-1-windowed.png` | Each toast is a window: same light, band and colour as the window it overlaps; its colour follows the field at its place, urgency only leans it (amber for critical, moss for low). |
| `glow-2-one-body.png` | The stack as one shape: the cards smoothly merged, the gaps become necks, the seams hairlines, the glow only on the outer outline. |
| `glow-3-docked.png` | The same body flush with the screen edge, as if it grew out of it. |
| `glow-arrival.png` | The arrival as one event: a front leaves the icon (the first design; the arrival below leaves the card's centre); the card is solid inside it and nothing beyond; the edge flares as the front crosses it; the ring goes on out into the screen. |
| `scene.png` | The window glow alone. |

Not designed yet: what the countdown becomes (the toast's own light dimming over its life is the candidate), the exit (the card
dissolving back into the light, with or without the spores), and critical/low colouring without a fixed palette.

### The settled glow look was built and then dropped
`look=glow` (a toast lit by the window glow's own light, with the arrival) was built, tested and judged on 2026-10-31; the user then said they
cared about the arrival, not the settled glow, and the look was removed. What it left: the window-lit settled look is in this repo's git
history (`p2/glow`), the mock-ups above stay as a record, and its arrival became the arrival below.

## The arrival (2026-10-31, `docs/design/arrival/`; moved here from the theme)
`arrival-one.png` (one toast, 60 ms to 3.3 s), `arrival-critical.png`, `arrival-low.png` and `arrival-burst.png` (three at once) are the real
shaders through the harness over a scene lit by the theme's real window glow (`arrival-mock.py`; the text is masked by the same front).
Why it is in this repo: the old ring came from a fixed 100x30 box near the corner of the screen because the theme cannot know where a card
is; the fork can, so the arrival is drawn from each card's real rectangle, corner radius and icon.
- **One wave, one timeline.** `p` runs 0 to 1 over 3.2 s (low), 4.2 s (normal) or 6 s (critical), times `motion_slowdown`; the front's radius from the
  icon is `(card reach + ring reach) * (1 - (1 - p)^3)`: quick off the icon, slowing. It crosses the card in about a fifth of the arrival (about a
  second for a normal toast); the ring reach is 26% of the screen's height, 180 to 340 px.
- **In the card** (`toastflare.frag`, `cardreveal.frag`): the card is shown only inside the front (a soft edge, `layer.effect` on the card while
  it arrives), its edge flares where the front crosses it and cools behind it (an afterglow), and the icon's spore is lit as the front leaves it.
- **Outside the card** (`toastring.frag`, one layer under the column): a pixel is reached by the front at `F = d + |icon - q|`, d its distance from the
  card's outline and q the nearest point of the outline, so the ring hugs the outline near the card (bulging where the icon is closest) and
  tends to a circle far away; the halo is a function of d alone, the lamp-glow in the card's shape, rising behind the front.
- **The hand-over**: the settled rim (the look's own, `ToastRim`) is held back until the front has crossed, then fades in as the flare falls
  (`rimGate`), and does not also ignite. Colours and amplitudes are the theme's old ring's (normal teal to blue, critical amber to pink, low moss to
  teal; critical 1.3, low 0.6, Omarchy's own toasts 0.7, a burst 0.6). A toast restored after a shell restart does not arrive.
- Not verified live: see checklist section H.

### The exit (2026-11-02): the arrival played backwards
`arrival/exit-one.png` (the real shaders, 0 to 1000 ms). When a toast expires or is right-clicked it no longer folds and fades: a front of light retreats across the card
from beyond its far edge to the icon, so the card **dissolves from its far corner into the light**; the ring and halo **contract onto the card and brighten** as they get there;
the settled rim is taken away by the same front as the card (a separate fade left the border lingering round the edges after the card had collapsed from them: the user noticed it live), so the border goes exactly as the card collapses; the flare's edge light follows the front with a short smear right behind it, 18 px (a 140 px ghost looked wrong in the mock-up; at 60 px a faint outline of the whole rectangle was still seen lingering
live after the card had collapsed from it, 2026-11-02); the spore at the icon goes out last. The spores the toast leaves are released a quarter of the way in, when the card starts to come apart. The slot folds
shut once the dissolve is 80% done so the stack closes up behind it (1.1 s in all, times `motion_slowdown`). It is the arrival's wave from the progress at which the front is
15% beyond the card (`ArrivalLogic.exitStart`, derived from the geometry so it holds on any screen) back to 0, at 1 s instead of 4.2 s, minus up to 30 px so nothing of the card
is left round the icon. Left-click and the IPC dismissals are still instant (as stock); `arrival=0` keeps the old 300 ms fold.

### The ring lingers (2026-11-02, "try"; branch `p2/arrival-linger`; `arrival/ring-linger.png`: the arrival at progress 0.03 to 1, the held ring at two moments, the exit at q 0.2 to 0.8, rendered with the shipped shader)
The arrival's ring no longer fades out after its few seconds and then reappears at the exit. The card is revealed at the same pace as before (the front's timing is unchanged), but
the ring now **comes to rest round the card and stays there for the toast's whole life** with the halo, a little dimmer than the passing ring, **undulating**: two plane waves travel
through it (its distance from its resting oval varies by about plus or minus 20% of 0.6 of the hold reach, wavelengths 90 to 140 px, periods 7 to 11 s), and its brightness breathes by 18%
and the halo's by 15%. The first ripple was a function of the angle round the card's centre, which pinched into a sharp kink across the middle of a wide card's top and bottom (seen in a
preview): plane waves in position are even.

**The shape, after the first live look (2026-11-02, from a recording).** The first version made the ring an offset of the card's outline, stopped by a clamp at a resting distance. Live that read
as two faults: "too card shaped" (a rounded rectangle, an octagon while the wave was still travelling, since the distance field of a rectangle's outline is not round) and "hitting an invisible
wall" (the clamp stopped the ring dead, all round at once). Now **the ring is an ellipse centred on the card**, semi-axes half the card plus 0.55 (across) and 0.8 (up and down) of the hold reach
(7% of the screen's height, 48 to 84 px; about 60 px above and 41 px beyond the ends at 1080p): wider than tall as a card is, but an oval, and as thick at the ends as on top (the first-order
ellipse distance). Its size is `ArrivalLogic.ringScale(front) = 1 - exp(-front / 110)`: it grows with the wave and **eases into its size with no stop** (63% at one ease length, 95% at three, which is
about 1.2 s into a 4.2 s arrival at normal speed). The halo is still the card's lamp-glow in the card's own shape (a card's glow is the card's shape). Lesson: a limit of a quantity that is
shown moving has to be approached, not clamped; and a shape meant to look natural should not be derived from the card's geometry unless it is meant to look like the card.

On expiry the ring shrinks from the size it has (`ringScaleExit`: the same curve normalised to start at that size) as the front retreats (`ArrivalLogic.exitFrom`, `exitFront`: slow at first,
quicker as it falls in, brightening up to 1.7 times), so it and the card dissolve together; a toast that leaves mid-arrival starts from where the front is then. A click or IPC dismissal removes the ring
at once. Held rings are updated at 30 Hz (frame by frame only while something moves fast). At most three rings at a time (the shader has three slots): a fourth toast takes the oldest ring's place.
Open for the user to judge: the oval's proportions (`0.55` and `0.8` in the shader), the ease length (`RING_EASE_PX`), the ripple, whether a critical toast's ring should rest for ever, whether more than three
rings are wanted. Note that at the top right of the screen the oval is cut by the screen's top and right edges (it is centred on the card).

### The toast as an oval, not a card (2026-11-02, branch `p2/oval-body`; mock-ups in `docs/design/blend/`, not committed: they contain a frame of a screen recording)
The user's brief again: the toast should blend into the arrival, not be a card inside it. Four mock-ups over the real ring on a frame of their screen: a feathered body (A), a translucent body lit from within (B), a pill (C). They chose A, found it "still way more of a
card", asked for a wider feather, then went back to A's feather (26 px: solid 16 px inside the outline, gone 10 px outside) and asked for **the card to be oval**. Three ovals were mocked (an ellipse 1.30 x 1.35 of the card; superellipses of exponent 3 and 4); they chose **exponent 3, 1.12 x 1.20**,
with **more padding between the text and the toast's edge**.
How it works: `toastbody.frag` draws the oval (a superellipse, first-order distance) as premultiplied fill in the card's colour with a faint edge light in the toast's colours; it lies under the card (the card's own fill is transparent), and the card's
layout gets 12 px more padding on each side and 6 above and below, which puts the text's corners about 4 px inside the solid zone (`BodyLogic.textClearance`; without the padding they were 7 px short of it, in the feather: the numbers were computed before building because the corners are the tight place for a
superellipse). `toastring.frag` no longer hides the glow behind the card (`shape` uniform): the body covers it, the feather lets it show through, and the halo hugs the oval; `toastflare.frag`'s edge flare follows the oval too. The blend rim's edge, spill, halo and countdown line are off with an oval body
(its soft edge replaces them; the icon ring and the faint spores stay). **The countdown line is gone for the blend look as a side effect** (it sat on the rectangle's bottom edge, which an oval does not have): if the user wants a countdown back, it has to follow the oval (an arc that drains along its lower edge is the obvious one).
Setting `body=card` restores the card; `look=growth` is always a card. Not verified: how it looks live (checklist section I).

**First live look (2026-11-02, a recording): "not very feathered looking, and the arrival effect's shape should better match the toast's."** Three causes, read off the frames:
- the 26 px feather was there, but the arrival's **halo sat at full strength right up to the oval's outline** (it was a function of the distance outside the outline only, so a plateau inside), so a bright cyan band hugged a dark oval and drew its edge: the feather read as an outline. Now the halo fades out going inward (`smoothstep(-0.45 * reach, 0, sd)`), the feather is **44 px wide (22 in, 22 out)** and the body takes on the glow's colour toward its outer edge (a dark fill fading over a bright glow reads as a smudge with an outline);
- the **ring was a true ellipse** with fixed axes (half the card plus 0.55 / 0.8 of the hold reach), so it hugged the oval's ends (about 20 px away) and floated 58 px off its top and bottom, and was rounder than the squarer toast. With an oval body the ring is **the toast's own superellipse a fixed gap (0.45 of the hold reach) outside it** (half the ring's irregularity too, so it keeps the shape);
- the **arrival's front was a circle** (the reveal mask, the edge flare, the halo's reveal), which cut an oval toast open in a round shape. It is an oval of the toast's proportions now (`aspect`, `BodyLogic.ovalAspect`; the reach it must go is `ovalFrontReach`).
**Second live look (a screenshot over a dark terminal): "still a hard edge".** Measuring the screenshot's luminance below the toast: flat and dark inside the body, then a narrow **bright ridge 24 px outside it** (+35 levels over the background), then a sharp drop. The ridge was the resting ring: making it parallel to the toast (the previous round) put it right against the soft body, where it read as the toast's own border, and on a flat background nothing else is there to hide it (over a busy wallpaper it was invisible, which is why the mock-ups looked fine). The body's own edge light and tint added a faint line too.
Fixed, tuned with `flat.py`-style renders (the shipped shaders over flat dark and light backgrounds, printing the luminance profile): the body is **only its fill and a feather** (no edge light, no tint); the lamp-glow that hugged the body is nearly gone in oval mode (amplitude 0.03, was 0.15); the ring is a **separate, wider, softer halo 0.75 of the hold reach (about 56 px) outside the body**, and is defined as the points a fixed distance from the body's own outline (offsetting the axes by equal amounts left 35 px at the corners against 55 at the top). The body's profile is now monotonic into the background on dark and light; the ring is its own ring. Lesson: judge an edge on a flat background as well as the real wallpaper; busy backgrounds hide exactly what a flat one shows.
**Third live look (a screenshot over a near-black terminal, after the ring was moved out): "that is not better".** The terminal was darker than the toast's fill, so the body was a *lighter* grey oval on black, and over terminal text it erased the text within about 15 px: a 44 px feather with the body 95% opaque inside it has a visible transition of only about half that. Flat mid-dark backgrounds (what the loop used) hid it. Fixed by making the fade **long and mostly outside the outline: solid 22 px inside, gone 58 px outside (80 px wide, `FEATHER_OUT`)**, so the body is 80% opaque at its outline and half there 18 px out. Judged on four backgrounds in the render loop (near-black, mid-dark, light, and a page of text); the body is a soft smudge into each. It makes the toast's visible footprint a little larger than its outline (the oval itself is unchanged, so the text clearance is too).
The ring-versus-body match is a test that measures the ring's distance from the body's outline at the top, bottom, ends and corners (a plain ellipse against the squarer body is 23 px apart; this is 14), and the sharper measurement direction (through the body's corners) was what let the ellipse mutation fail it.

### The arrival leaves the card's centre; the column can be centred on the screen (2026-11-02, "try")
The user asked to try the toasts at the **top centre of the screen** (they are at the top right, as in Omarchy) and the arrival **centred on the toast**: with the wave leaving the icon, which sits at the
card's left, the ring seemed centred on the toast's top-left corner. Now the wave starts at the card's centre (`ArrivalFlare.origin`; a small spark there spreads into the front, `toastflare.frag`'s
`origin` uniform), the reveal is a disc growing from the middle to both ends, the ring and halo are symmetric about the card, the icon's ring lights as the front reaches it, and the exit retreats to
the centre. The card reach is from the centre (about 225 px for a 380x78 card, not 381), so the front crosses the card in about 0.6 s of 4.2 s, a little quicker than before. `arrival-one.png`,
`arrival-critical.png`, `arrival-low.png`, `arrival-burst.png` and `exit-one.png` were regenerated. `position=center` in the fork's conf file centres the column (the spore layer is 900 px wide and centred
on it, so spores can drift left of any card); `position=right` is the default. Both are theme-gated like everything else here.
