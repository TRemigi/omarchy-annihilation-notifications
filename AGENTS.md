# AGENTS.md

Guide for an agent (or contributor) continuing work on **omarchy-annihilation-notifications**. Read this,
then `README.md`, `CONTRACT.md` and `docs/plan.md`, before changing anything.

## What this is

A fork of Omarchy's notification daemon (`shell/plugins/notifications` in the `omarchy` package, MIT),
installed as a *registered clone* of `omarchy.notifications` so that Omarchy routes everything that used
to talk to the stock daemon to this one, and switches the stock one back on when this is disabled or
removed. It belongs to the **omarchy-annihilation-theme** project (a sibling repo, `../omarchy-annihilation-theme`),
whose `docs/notifications-fork.md` is the same plan plus the theme-side tasks, and whose `docs/notifications.md`
describes the notification features it already has (arrival glow, sound, missed-notification marks) that read
this daemon's state files.

Phases (details in `docs/plan.md`): **P0** functional parity (done and live-verified);
**P1** tooling, runbooks, fallback (partly done); **P2** the actual experience, theme-gated (slice 1, the motion, is released as 0.2.0); **P3** integration
with the theme's plugin, automatic fallback, CI. **The live checklist has passed on a real session (2026-10-30), so P2 may start**,
but do P1's remaining safety items first (see Open items). Parity first is the whole point: it proves install, update and fallback on a fork that
changes nothing.

## Rules

- **Never edit `/usr/share/omarchy`.** It is the installed package, read-only, overwritten by pacman. Read it freely.
- **Keep the contract** (`CONTRACT.md`): the IPC target and its functions, the `doNotDisturb` /
  `setDoNotDisturb` members, the state-file format and names, the layer namespace, the DND and lifetime
  rules. Changing one means changing its callers, so say so in the commit and in the theme repo.
- **The `upstream` branch is only ever written by `tools/import-upstream`.** Never commit to it by hand.
  `UPSTREAM` and `reference/` are generated and only change there.
- **Keep merges small.** Prefer new files plus a thin hook in a vendored file over editing deep inside one.
  Every change to a vendored file is marked with a `// annihilation:` comment (a new file needs no marker),
  so that a conflict in a merge can be read. `git diff upstream main -- Service.qml NotificationLogic.js components`
  is exactly what this fork has changed; at the end of P0 it is empty.
- **Fork code is theme-gated** (from P2): it must behave exactly like stock unless the active theme is
  `annihilation` (read `~/.local/state/omarchy/current/theme.name`, as the theme's plugin does).
- **Never ship something that can leave a user with no daemon** without the fallback tooling covering it.
- Explicit paths in `git add`; small commits that say why; follow the attribution trailer the session asks for.
- Preferred voice with the user: concise, honest about what is unverified, no repeated permission questions
  once a direction is agreed. Creating or pushing to a GitHub repo is outward-facing: ask first.

## Gotchas (each verified by reading Omarchy 4.0.4-1, or cost time in the theme repo)

- **The registry does the swap.** `omarchy.clonedFrom` in the manifest makes `resolveEnabledId` route
  calls (including `firstPartyServiceFor("omarchy.notifications")`, which the bar's DND button uses) to the
  enabled clone, adds `omarchy.notifications` to `disabledPlugins[]` while it is enabled, and restores it
  on disable or remove (`shell/services/PluginRegistry.qml`, `cloneSourceRestores`).
- **If this plugin fails to load, there is no daemon** (the stock one is already off). Hence the fallback
  runbook and the live checklist; and: *do not delete or rename the plugin folder to "disable" it*, the stock
  plugin stays listed in `disabledPlugins[]` and nothing runs.
- Plugin ids may not start with `omarchy.`; this one is `annihilation.notifications`. `omarchy plugin
  validate` refuses a symlinked folder: validate the real path.
- **`keepLoaded: true` blocks hot reload**, and **a new QML file needs `omarchy restart shell`**, not just
  `rescanPlugins` (the theme's user hit this). After any edit, tell the user to restart the shell.
- A bare `notify-send` is app name `notify-send`, which the daemon treats as *ephemeral*: under DND it is
  dropped and never recorded. Test the silenced path with `notify-send -a Signal "x" "y"`.
- A hash change in a watched file means "look", not "broken"; a clean hash does not prove the fork works
  (a renamed `Style` token breaks the QML without touching our files). That is what qmllint and the live
  checklist are for.
- The fork's QML imports `qs.Commons` and `qs.Ui`; the shell provides them to third-party plugins too.

## How to verify (this sandbox has no compositor or Quickshell session)

```bash
bash test/tools-test.sh          # import-upstream and check-upstream, against a scratch Omarchy (47 checks)
node test/logic-test.js          # NotificationLogic.js (35 checks)
bash test/motion-test.sh         # components/SlotMotion.qml, offscreen with the real Qt Quick runtime (22 checks)
bash test/growth-test.sh         # shaders/toastgrowth.frag through the harness (44 checks, stale for the roots: see below)
bash test/service-probe.sh       # the REAL Service.qml in an offscreen Quickshell (26 checks, ~30 s): the theme gate on,
                                 # off and switched live, motion_slowdown, the setting parser. Only the layer-shell
                                 # window type is swapped for a plain one in a copy; everything else is as shipped.
bash test/motion-filmstrip.sh DIR   # renders a stand-in toast stack to DIR/sheet.png (needs ImageMagick): look at it
omarchy plugin validate .
tools/check-upstream             # exit 0 when the installed Omarchy matches the baseline
T=$(mktemp -d); ln -s /usr/share/omarchy/shell "$T/qs"
/usr/lib/qt6/bin/qmllint -I "$T" -I /usr/lib/qt6/qml Service.qml components/NotificationCard.qml
```

qmllint baseline on Omarchy 4.0.4-1: `Service.qml` 17 warnings (15 in stock; P2 slice 1 added two more
"unqualified access", `service.` used inside the delegate and the settings `FileView`, the same class the file already has)
(unqualified access x12, `PanelWindow` not creatable, `QProcess::ExitStatus` not found x2, `sizeVertical` /
`sizeHorizontal` not found on `QObject`), `components/NotificationCard.qml` 12 (members not found on
`QObject`: `text`, `title`, `icon`, `displayLarge`, `countdown`, `border`, `background`). New warnings that
name `Style`, `Color`, `Border` or `Util` members mean the shared API moved.

Habit that paid off: after writing a test, break the code under test on purpose and confirm the test fails.
In this repo it exposed four holes in the tools' own tests.

Nothing visual or live can be confirmed here. `docs/runbooks/live-checklist.md` is what the user runs, and
its results table is where outcomes are recorded.

## State at the end of the first session (P0)

Built and checked here: the repo; `upstream` branch (tag `upstream/4.0.4-1`) and `main` (the merge plus the
manifest); `tools/import-upstream` and `tools/check-upstream` and their tests; `test/logic-test.js`;
`CONTRACT.md`; the update, fallback, release, troubleshooting and live-checklist runbooks.
`omarchy plugin validate .` passes and `tools/check-upstream` exits 0.

**Verified live by the user (2026-10-30, Omarchy 4.0.4-1):** installed with `omarchy plugin add` from the
pushed repo, and every item of `docs/runbooks/live-checklist.md` passed: the takeover, behaviour against
stock (DND, `omarchy-notification-send`, restore after a shell restart) and the disable-and-restore cycle.
They gave no per-item notes, so it is not recorded whether the restore needed `omarchy restart shell`.

Decisions already made with the user: a separate repo registered as a clone (not a patch); parity first;
the fork behaves as stock off the annihilation theme (no theme-switch daemon swapping); track packaged
Omarchy releases only, not the dev/edge channels; **automatic fallback on by default** (P3). Still open:
nothing in P0. The repo is **public** at `https://github.com/TRemigi/omarchy-annihilation-notifications`
(owner TRemigi; `origin` is the SSH URL, as in the theme repo). The user created and pushed it; the agent's
sandbox could not (`gh` token invalid). Commits use the GitHub noreply address
(`63087524+TRemigi@users.noreply.github.com`) from the user's global git config; the history was rewritten once
to remove an earlier work address, so do not reintroduce one. See "First push" below for how it was done.

Open items, in order: `tools/contract-check`, `tools/status`, a `fallback` tool and CI (P1); then this repo's counterpart in the theme repo (`extras/install notifications ...`,
post-update and post-boot hooks, README section), which lives in **that** repo; then P2.

## First push (done by the user, from their own shell)

```bash
gh auth login -h github.com                       # the stored token was invalid
gh repo create TRemigi/omarchy-annihilation-notifications --public \
  --description "Themed notification daemon for Omarchy: a registered clone of the built-in"
# (origin is already set to git@github.com:TRemigi/omarchy-annihilation-notifications.git, so no --source/--remote)
git push -u origin main                           # main first, so it becomes the default branch
git push origin upstream --tags                   # the upstream branch must be pushed too
```

`--public` is needed for `omarchy plugin add <https url>`, which runs without credential prompts; a private
repo only works with the SSH URL. Public means the git history, including the author email, is visible.

## P2: the experience (in slices, each judged live before the next)

The look was chosen from mock-ups on 2026-10-30 (`docs/design/`): a blend of A (Refraction, the base, toned down),
B's Cinzel small-caps header and C's spores; the full C "Growth" direction is a tracked follow-up experiment. Slices
(renumbered): **1 Motion** (released as 0.2.0), **2 The look** and **3 The countdown** (released as 0.3.0; the user confirmed both live, the countdown after two fixes from their screenshots): toasts unfold into the stack
and fold away (expiry and right-click; click and IPC dismissals stay instant). **2 The look** (iridescent rim, typography, ring
icon; branch `p2/look`), **3** the countdown (a line of light that drains), **4** spores on exit, **5** a switch for
the look and the motion, and a follow-up experiment, **6 Growth**. Do not build the next slice before the user has seen the last.

How slice 1 works, so it is not re-derived:
- `components/SlotMotion.qml` is a small non-visual item per delegate with `presence` (0 to 1) and `enter()` /
  `leave(done)`. The slot binds `implicitHeight: card.implicitHeight * heightFactor`, `Layout.bottomMargin:
  spacingTrim` (folds the column's 8 px gap away with the slot), `clip: clipping`, and the card's `opacity` and
  `scale` (transform origin top right). Entry 480 ms on an ease-out cubic, exit 300 ms on the theme's `exhale`
  curve, each multiplied by `motion_slowdown`. **The first version (340 ms on `tendril`) was too quick**: measured in a
  real Quickshell it was 75% done after five frames (80 ms), and the user, on the branch, said notifications "look the
  same". It was working (verified by `test/service-probe.sh`); it just read as a pop. Lesson: judge a curve by its
  samples (`test/motion-test.sh` now asserts the entry is not front-loaded), and give the user a way to exaggerate it.
- Gated by `Service.themed` (a `FileView` on `~/.local/state/omarchy/current/theme.name`): with the theme off,
  `enter()` does nothing, `leave(done)` calls `done` at once and every factor is 1, so it is stock. Switching theme
  takes effect without a shell restart.
- `leave` is used for expiry (the timer) and right-click; the service function is called when the fold ends, with
  the index read then (it moves as other toasts come and go). `ticking` is false while leaving, so the countdown does
  not run twice. Left-click (`invokePopupDefault`) and the IPC dismissals remove the row at once, as stock.
- Layout trap found and solved in the filmstrip: a slot of height 0 still adds the column's spacing, so the gap would
  pop open; the negative bottom margin folds it away. Clipping is only on while presence < 1.
- `~/.config/omarchy/annihilation-notifications-fork.conf` is the fork's own settings file (not the theme repo's
  `annihilation-notifications.conf`, which holds the guard's `auto_fallback`): `key=value` lines, watched live. Only
  `motion_slowdown` (0.25 to 8) so far. Keep the two files separate; the theme's `auto` command rewrites its whole file.
- Judged by `test/motion-filmstrip.sh` (rendered with software Qt offscreen, a plain-rectangle stand-in for the card)
  and `test/motion-test.sh`; the real card (`BorderSurface`, the gradient border) under scaling is only checked live.
  Likely live issues: a blurred or cut border during the scale, flicker with several toasts.

## P2 slices 2 and 3: the look and the countdown (released as 0.3.0 on 2026-10-30)

Built from the design chosen on 2026-10-30 (`docs/design/`: mock-up A toned down, B's header, C's spores later):
- `shaders/toastrim.frag` (+ committed `.qsb`; rebuild with `tools/build-shaders.sh`) draws, as added light, an
  iridescent rim (a narrow slice of the spectrum across the card, brightest toward the top right), a prism spill just
  inside, a faint halo outside, and a ring with a spore round the icon. It works in logical px (the QML passes
  logical sizes; the preview renders at 2x but passes logical values), is premultiplied with alpha 0 (additive, as the
  theme's other shaders) and rolls off with `1 - exp(-x)`. Uniforms: `energy` (1 settled; 2.2 igniting), `vividness`
  (0.75), `urgency` (0 low, 1 normal, 2 critical, the `NotificationUrgency` numbers), `radius`, `size`, `card`, `icon`, `time`.
- `components/ToastRim.qml` lies over the card (a sibling in the slot, so it can anchor to it; it follows the card's
  scale and opacity), takes no input, ignites on creation (energy 2.2 to 1 over 1.1 s after a 120 ms pause, times
  `motion_slowdown`) and ticks `time` at 15 fps. Invisible, so nothing is drawn, with the theme off.
- `components/NotificationCard.qml` (marked edits): `themed` property; when set, Omarchy's border is made invisible with
  `Border.flat("transparent", 2px)` (same width, so the layout is unchanged), Jost replaces Liberation Sans (weights
  500 title and 380 body through `font.variableAxes`), a caption row (the app in Cinzel capitals, amber, and "now" /
  "N min") goes above the title, the title has a blurred copy behind it as a faint glow (`MultiEffect`), and
  `iconRing` says where the icon is (centre x = border + 12 + 20, centre y = half the height; radius 26 around an app
  icon, 17 round a glyph, none when the icon slot is hidden). With `themed` false none of it applies.
- **Slice 3, the countdown (same branch):** the shader's `remaining` uniform (0 to 1; negative for none) draws a line
  along the bottom edge (3.2 px up; **border to border** when full: from the left rim (0.9 px in, plus the little a rounded
  corner pulls the border in at that height) to the same on the right, times `remaining`) with a glow and a
  bright spark at its right end; its colours are fixed along the full length, so it retreats instead of recolouring, and it
  fades over the last 8%. The delegate passes `cardSlot.remainingLifetime` (the toast's own clock, so it freezes on hover
  and restarts on an update) or -1 when the toast never expires (critical). Previews: `docs/design/shader-countdown.png` (62% left) and
  `shader-countdown-full.png` (a fresh toast). **Two earlier versions fell short, and both were reported by the user from screenshots:** the first was inset 14 px at each
  end; the second ran from corner to corner (radius + 1 px in), which still left a dark gap of about 5 px at each end
  between the line and the border: "it should go all the way to the left border". Lesson: a line meant to fit a rounded
  card has to meet the *border*, not stop where the corner starts. The tests now check the ends at three corner radii
  (0, 4, 10). The first version was inset 14 px at each end, so even a fresh toast's line
  stopped short of the card and a half-drained one looked arbitrary; the user reported "the line at the bottom doesn't fit the
  length of the card". Measured from their screenshot first: the line's start (14 px in) and its drain were exactly as coded
  (a toast under a second old was 89% drained), so it was a design miss, not a bug. Note: their screenshots are **window
  captures** that crop the toast column at the window's right edge, so toasts look cut off in them; that is not a layout bug.
- `fonts/`: Jost and Cinzel (SIL OFL) copied from the theme repo.
- Setting `rim_vividness` (0 to 1, default 0.75) next to `motion_slowdown` in the fork's conf file.
- Verified: `test/shader-test.sh` (38 checks on the compiled shader through the harness: where it draws, the light's
  direction, ignition, palettes, ring, additive, no flat clipping, vividness, drift, the countdown, and that the shader's
  uniforms and ToastRim's ShaderEffect properties are the same set; 15 deliberate breaks caught, one equivalent);
  `test/service-probe.sh` (55 checks: the REAL `Service.qml` and card in an offscreen Quickshell, including that with the
  theme off every card is the **same size as Omarchy's pristine card** and keeps its border; 8 deliberate breaks of the
  card edits caught); `test/rim-preview.py` renders the shader over a backdrop (`docs/design/shader-*.png`).
- **Not verified, needs the user** (section E of the live checklist): how it actually looks (taste), the title glow's
  `MultiEffect` in a real shell, the ring round square app icons, several toasts' halos together, and that it does
  not feel heavier. A first lesson from section D applies: if it "looks the same", check the branch and the
  `p2/look` code is what runs before concluding anything.
- Lint baseline now: `Service.qml` 26, `NotificationCard.qml` 14, `ToastRim.qml` 0 (the same classes as before).

## P2 slice 4: spores (released as 0.4.0 on 2026-10-30; the user reported "the spores look good")

Plan: the exit dissolves into spores, and a faint drift off a card. Both are built (the drift is the second commit on the branch). **The exit burst**:
- `shaders/toastspores.frag` (+ `.qsb`): up to four bursts of 22 spores each, computed from a hash of the burst's seed (no
  particle objects): they lift off the card's body over 0.28 s, drift **left** 28 to 102 px (ease-out, with a little sway), and
  fade over 0.9 to 1.7 s; amber and the toast's own colour (teal, pink for critical, green for low). Additive, rolled off with
  `1 - exp(-x)`. **Direction is left, not up as in the mock-up**: the toasts sit in the top-right corner, so there is no room
  above, and down would cross the toast below. A pixel far from every burst returns early.
- `components/SporeLayer.qml`: lives in the popup window over the stack (`Style.space(380) + 260` wide, up to `Style.space(720)`
  tall, top right), because a toast's own item is gone after its 300 ms fold and the spores last 2.2 s. `burst(x, y, w, h,
  urgency)` takes the card's rect in layer pixels and a random seed; a `FrameAnimation` runs only while a burst is alive;
  invisible and costless otherwise; click-through (`enabled: false`).
- `components/SlotMotion.qml` emits `leaveStarted()` when a fold begins; the delegate's `releaseSpores()` (`card.mapToItem` the
  layer) fires on that and on a click (a click removes the row at once, with no fold). `SporeLayer.amount` is
  `themed ? spore_amount : 0`, so another theme gets none.
- `Service.qml` (marked edits): the window's `visible` is now `popupModel.count > 0 || sporeLayer.active` so it stays up for the
  spores (CONTRACT.md notes it); `spore_amount` (0 to 1, default 1) in the fork's conf file, with `parseSpores`.
- Verified: `test/spores-test.sh` (21 checks on the shader through the harness, including a one-spore variant that proves each
  spore eases in and out; 10 deliberate breaks caught, one equivalent: the burst-level 2.2 s cutoff is redundant with each
  spore's own end); `test/service-probe.sh` (76 checks; its spore scenarios run in a config root where toasts last 0.7 s, and
  cover expiry, click, another theme, `spore_amount` 0 and 0.5, the window staying up for the spores and then going, and the
  parser; 6 deliberate breaks caught); `test/spores-preview.py` renders `docs/design/spores-exit.png`.
- Two test pitfalls hit here, worth knowing: `VAR=1 out=$(run ...)` does **not** export `VAR` into the substitution (it is two
  shell assignments), which made a click scenario silently not click and two mutations survive; write `out=$(VAR=1 run ...)`.
  And shortening toast lifetimes must be done in its own config root, or it breaks every other scenario.
- **The faint drift** is in `shaders/toastrim.frag` (not a new component): six spores per toast, each with its own period (5 to
  8.5 s), leaving the card's **left** edge and drifting 46 px away with a little sway and a fade in and out, only ever drawn to the
  left of the card (a mask at the edge), scaled by the `spores` uniform (`spore_amount`) and by 0.55 so they stay faint. `ToastRim`'s
  overlay margin went from 20 to 56 px to hold them, and the shader's early-out from 40 to 60 px. `shader-test.sh` now has 51 checks:
  the spores' presence, that they stay left of the card and within 56 px, level with it, faint and few, that they move, how far
  they reach and that nothing is hard-clipped at the edge of their area, where they sit vertically, that `spore_amount` scales
  them to nothing (aggregated over eight moments, and compared like for like: **the rim's own colour drifts with time too**, so
  comparing a frame at one time with a frame at another measures the rim, not the spores). `test/rim-preview.py` takes
  `[spores] [time]`: `docs/design/shader-ambient.png`. The service probe is at 76 checks (the `spores` property reaches the rim for
  1, 0.5 and 0). One mutation is near-equivalent: removing the mask that hides spores over the card only trims 1 to 4 px of glow
  tail at the edge.
- **Not verified, needs the user** (checklist section F): how the spores look and feel (taste: size, count, brightness, direction),
  that nothing flickers when the last toast goes, and that the layer never intercepts input.

## P2 slice 6: Growth (experiment, branch `p2/growth`, not released)

`look=growth` in the fork's conf file (parsed by `parseLook`, `blend` otherwise) makes `ToastRim` load `shaders/toastgrowth.frag`
instead of `toastrim.frag`; same overlay, same added-light output, same uniforms plus `seed` (random per toast) and `growth`
(0 to 1: how far through its life the toast is, from `1 - remaining` and never decreasing, so the roots grow over the whole life, each with its own start and finish, the last by 99.5%, via `rootReach` in the shader: a burst over the first ~1 s with a slow creep after; a toast without a countdown, i.e. critical, animates it over 8 s times `motion_slowdown`). `ToastRim`'s margin is 110 px for the roots. Both shaders declare the **same uniform
set** (the blend's `seed` and `growth` are unused) so `ToastRim`'s ShaderEffect feeds either; `shader-test.sh` and
`growth-test.sh` both check that. What the design does and why (the mock-up's wavy outline and ragged strip read as glitches, so
the outline stays straight and is alive instead; lichen is jittered dots; veins are curves with branches that cannot reach the
toast below) is in `docs/design/README.md`. Verified: `test/growth-test.sh` (44 checks; every deliberate break caught but one equivalent: removing the veins' distance early-out, since no vein is longer than it); `test/service-probe.sh` (86: the
parser and that `look` reaches the rim). **Not verified, needs the user** (checklist section G): how it looks next to the
blend. The preview needs numpy and pillow, which this sandbox lacks: `python3 -m venv $TMPDIR/v && $TMPDIR/v/bin/pip install numpy pillow`
works (the network is open to PyPI).
**After the user's live test (2026-10-31, recording in ~/Videos):** the user liked it, asked for the countdown to lie *exactly on* the bottom
border (it ran 3 px above and read as two lines; now it is the rim's own distance field plus sway, lit and undulating in thickness,
so it cannot drift off the border; confirmed good) and for "a lot more" of something they called lichen. **I read that as lichen and was
wrong**: I made the dots 3 to 7 times denser and deeper and the user said it was too much and in the way. They meant the root-like
growths (the veins) coming out of the card. So: the lichen is back to its first version, and the veins are now roots, about one per
10 px of the card's height along the whole left edge. Lesson: when a request names a feature, check against the recording which
element is meant before multiplying it. Test lessons from that round: the alignment check first used the brightest row, which let both
a 3 px offset and a missing sway through (the border outshines the line); it now compares centroids column by column against a growth-0
render where the border is alone. And dots larger than the 3x3 cell search are cut flat, which only showed in a zoomed preview: look at
previews zoomed. **The roots change was committed without running the growth tests** (the user asked not to run the full path every
time): the vein checks in `test/growth-test.sh` were written for four veins and may need their thresholds revisited; run it and
fix before releasing.

**Roots, round 3 (2026-10-31):** left roots cut to one per 18 px, longer (scale 1.0 to 1.5), and the roots grow over the toast's life as above. Also
committed **without running the tests** at the user's request: `test/growth-test.sh` treats `growth` as an arrival animation (growth 0.5 = half
grown) and the vein regions assume the old lengths and the 30 px left margin of its overlay; expect to revisit it.

**Roots, rounds 4 to 7:** the growth curve was judged wrong six times live (see `docs/design/README.md` for the list). It is now `easeGrowth`
in the shader: `smoothstep(0, 0.15, t) * (0.75 * (1 - exp(-5t)) / (1 - exp(-5)) + 0.25 * (1 - (1-t)^1.5))` per root between its start
(first 8% of the life) and its finish (97 to 99.5%). A cubic Bezier cannot be both fast in the body and decisive at the end; an
exponential slowdown has a constant speed ratio per unit time, which is what reads as natural, but alone it is *visually finished* after
about four seconds (speed under 2 px/s), so a quarter of the curve is a gentle ease-out that keeps moving to the end. Lessons: prototype
curves numerically against target samples (1, 2, 3, 4, 6 s of an 8 s toast) *and the speed in px/s at 1, 2, 3, 5 and 7 s* (a speed under
about 2 px/s does not read as growth) before touching the shader, then measure the compiled shader's reach at the same points (render at
`U_growth=g` with the card at x=130 in `test/shader-harness.c` and take the leftmost lit pixel; the stagger of starts makes the measured
body a few points slower than the ideal curve); a linear component makes the curve look linear whatever the rest does, but a small one
rescues a dead tail; and an ease-in is what stops a pop. The lengths: the roots are 1.4 to 2.0 times the old length on the left and 1.1 to 1.7 on the bottom, with 16 steps per trunk. Cost
went up (a vein is now ~45 loop iterations; `vein()` returns early beyond its grown radius). Untested apart from renders.

**Roots, round 8 (2026-10-31, from a screen recording):** the user said the roots "still finish (or appear to finish) well before the
countdown" even with the curve they liked. Measured from the recording (a high-pass filter to find thin bright lines, per band below and
left of the card) and from the shader (lit pixels outside the card, minus the g=0 baseline, at several `U_growth`), the visible ink was
96% complete at 3 s of 8 and 99% at 5 s: the trunk curve is fine but the eye reads a root as finished once what is left is a few pixels.
The fix kept the trunk curve and added **four shoots per root on later schedules** (`shootReach`: starts ~10/30/50/70% of the life, full at
97 to 99.5%); `vein()` is now one loop that draws the trunk and spawns the shoots (no `walkTo`). Lesson: judge "appears finished" by
visible *ink* over time (video or harness), not by the trunk's length curve; and when two requests pull against each other (a strongly
decelerating curve vs growth to the very end) look for a way to give the eye something moving instead of bending the curve.
Untested apart from renders and the ink measurement.

**Roots, round 9 (2026-10-31): tuning "apparent activity".** The user wants the roots alone to be able to show the toast's timing (the
countdown line could then go), and said the activity lessened too soon. `test/growth-activity.py` measures the per-second visible ink on
the compiled shader like the recording (agrees within ~5 points); the trunk curve hardly moves it, the shoot schedule does. Result: trunk
65% exp(3.5) + 35% ease-out, shoots from 16% of the life in 16% steps with ease power 1.5; gains 34/25/13/11/8/6/2 per second (were
43/19/12/9/8/6/3). **Do not run searches with a bare `&` or `( ... &)`**: the process is killed when the command ends, and nothing is
printed until the end of a long script. Use `run_in_background` and print each result as it arrives (threads, not processes: the sandbox
forbids the unix sockets multiprocessing needs). The remaining question is whether the user judges it good enough to drop the countdown line.

## Conventions

- Match the surrounding (Omarchy's) QML style in vendored files: terse comments that explain why, no tutorials.
- Shell tools: `set -euo pipefail`, `jq`, no dependencies beyond what Omarchy already requires; exit codes are
  documented at the top of each tool.
- Runbooks say what to run and why, and what each outcome means. Keep them true: update them in the same
  commit as the behaviour they describe.
