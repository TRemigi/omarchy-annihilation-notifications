# AGENTS.md

Guide for an agent (or contributor) continuing work on **omarchy-annihilation-notifications**. Read this,
then `README.md`, `CONTRACT.md` and `docs/plan.md`, before changing anything.

## What this is

A fork of Omarchy's notification daemon (`shell/plugins/notifications` in the `omarchy` package, MIT),
installed as a *registered clone* of `omarchy.notifications` so that Omarchy routes everything that used
to talk to the stock daemon to this one, and switches the stock one back on when this is disabled or
removed. It belongs to the **omarchy-annihilation-theme** project (a sibling repo, `../omarchy-annihilation-theme`), which
holds the code that installs and guards it (see `docs/theme-integration.md` here) and whose `docs/notifications.md` describes the
notification features its own plugin has (arrival glow, sound, missed-notification marks) that read this daemon's state files.
**This repo is the only home of the fork's plan and design; the theme repo does not mirror it or track its versions** (it used to; do
not bring that back).

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
  once a direction is agreed.
  **Whenever a change needs the user to do something live, end with copy/paste-ready commands**, one block, in order (sync the installed
  clone, restart the shell, set the conf line, send the test notifications), each safe to paste as it stands. The installed fork is a
  separate git clone in `~/.config/omarchy/plugins/annihilation.notifications`, **deliberately not symlinked** to the dev repo (a broken
  edit would then be the live daemon, and `omarchy plugin update` would pull inside the dev repo; the user declined it on 2026-10-31).
  Syncing without pushing: `git -C ~/.config/omarchy/plugins/annihilation.notifications fetch ~/dev/omarchy-annihilation-notifications <branch> && git -C ~/.config/omarchy/plugins/annihilation.notifications checkout -q -B <branch> FETCH_HEAD`.
  The sandbox cannot write under `~/.config`, so the user runs these (with the `!` prefix if they like). Creating or pushing to a GitHub repo is outward-facing: ask first.

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
bash test/growth-test.sh         # shaders/toastgrowth.frag through the harness: rim, veins, lichen, ring, the shadow, no countdown line (30 checks, a few minutes)
bash test/growth-roots-test.sh   # the roots: reach, count, no pop at the start, staggered starts, still growing late, done at the end (25 checks, ~1 min)
$TMPDIR/venv/bin/python3 test/growth-activity.py FRAG   # not a pass/fail test: the per-second visible root ink, as measured on a recording
python3 test/arrival-test.py     # toastring.frag, toastflare.frag and cardreveal.frag through the harness (47 checks, ~10 s)
node test/arrival-logic-test.js  # ArrivalLogic.js (32 checks)
bash test/service-probe.sh       # the REAL Service.qml in an offscreen Quickshell (26 checks, ~30 s): the theme gate on,
                                 # off and switched live, motion_slowdown, the setting parser. Only the layer-shell
                                 # window type is swapped for a plain one in a copy; everything else is as shipped.
bash test/motion-filmstrip.sh DIR   # renders a stand-in toast stack to DIR/sheet.png (needs ImageMagick): look at it
omarchy plugin validate .
tools/check-upstream             # exit 0 when the installed Omarchy matches the baseline
T=$(mktemp -d); ln -s /usr/share/omarchy/shell "$T/qs"
/usr/lib/qt6/bin/qmllint -I "$T" -I /usr/lib/qt6/qml Service.qml components/NotificationCard.qml
```

qmllint on the fork now (2026-10-31): `Service.qml` 29, `NotificationCard.qml` 14, `ToastRim.qml` 2 (`igniteAnim` / `growAnim` used inside a function: the same "unqualified access" class). The original baseline on Omarchy 4.0.4-1 was: `Service.qml` 17 warnings (15 in stock; P2 slice 1 added two more
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
B's Cinzel small-caps header and C's spores; the full C "Growth" direction was a follow-up experiment, now released (0.5.0) as an opt-in look. Slices
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

## P2 slice 6: Growth (released as 0.5.0 and refined in 0.6.0, 2026-10-31; opt-in with `look=growth`)

`look=growth` in the fork's conf file (parsed by `parseLook`, `blend` otherwise) makes `ToastRim` load `shaders/toastgrowth.frag`
instead of `toastrim.frag`; same overlay, same added-light output, same uniforms plus `seed` (random per toast) and `growth`
(0 to 1: how far through its life the toast is, from `1 - remaining` and never decreasing, so the roots grow over the whole life, each with its own start and finish, the last by 99.5%, via `rootReach` in the shader: a burst over the first ~1 s with a slow creep after; a toast without a countdown, i.e. critical, animates it over 8 s times `motion_slowdown`). `ToastRim`'s margin is 110 px for the roots. Both shaders declare the **same uniform
set** (the blend's `seed` and `growth` are unused) so `ToastRim`'s ShaderEffect feeds either; `shader-test.sh` and
`growth-test.sh` both check that. What the design does and why (the mock-up's wavy outline and ragged strip read as glitches, so
the outline stays straight and is alive instead; lichen is jittered dots; veins are curves with branches that cannot reach the
toast below) is in `docs/design/README.md`. Verified: `test/growth-test.sh` (35 checks) and `test/growth-roots-test.sh` (25 checks), every deliberate break caught but one equivalent (removing the veins' distance early-out, since no vein is longer than it); `test/service-probe.sh` (86: the
parser and that `look` reaches the rim). All suites were run and passed on 2026-10-31 after the roots work (the roots were built without running them, at the user's request). **Not verified, needs the user** (checklist section G): how it looks next to the
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
previews zoomed. (The roots were committed without running the growth tests, at the user's request; they were run and fixed afterwards: see below.)

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
Untested apart from renders and the ink measurement (tests added afterwards).

**Tests for the roots (2026-10-31):** running the old `test/growth-test.sh` after the roots work found two stale checks only (that veins fade within 18 px of the card, and that nothing hangs below it), which were removed. The roots got their own file, `test/growth-roots-test.sh`, with a 440x240 overlay and the card at (130,30) (room for 80 to 95 px roots). Thresholds come from measured values across four seeds (left reach 80 to 94 px, below 68 to 75, 4 to 6 roots crossing a line beside the card). 11 deliberate breaks: 9 were caught at once; "no stagger" and "roots stop at 80%" got through and led to two sharper checks (the count of bottom roots out at 9% of the life, which is 0 to 1 of 16 to 17 with the stagger and 8 without; and reach at least 70 and 58 px). Lesson: a stagger shows in *how many* roots are out early, not in how far the farthest has got.

**Roots, round 9 (2026-10-31): tuning "apparent activity".** The user wants the roots alone to be able to show the toast's timing (the
countdown line could then go), and said the activity lessened too soon. `test/growth-activity.py` measures the per-second visible ink on
the compiled shader like the recording (agrees within ~5 points); the trunk curve hardly moves it, the shoot schedule does. Result: trunk
65% exp(3.5) + 35% ease-out, shoots from 16% of the life in 16% steps with ease power 1.5; gains 34/25/13/11/8/6/2 per second (were
43/19/12/9/8/6/3). **Do not run searches with a bare `&` or `( ... &)`**: the process is killed when the command ends, and nothing is
printed until the end of a long script. Use `run_in_background` and print each result as it arrives (threads, not processes: the sandbox
forbids the unix sockets multiprocessing needs). The remaining question is whether the user judges it good enough to drop the countdown line.

**Post-0.5.0 iteration, branch `p2/growth-roots-3d` (2026-10-31):** the user asked to remove the countdown line (the roots are now the timer)
and make the roots a little thicker and more 3D. In `toastgrowth.frag`: the countdown block is gone (`remaining` stays declared for the
uniform-parity contract); `curve()` is replaced by `tube()` (a round tube with a soft edge, cylinder shading from a light at the top right,
specular, and a shadow offset down-left), `over()` and `shoot()`; `vein()` returns `vec4(cover, diffuse, specular, shadow)`; the output now
has **alpha > 0 for the shadow only** (premultiplied: light in rgb, darkening in alpha), so **`test/growth-test.sh`'s "alpha is 0 everywhere"
check and its countdown checks are stale, and the roots test's thresholds are untested on thicker roots.** Committed without running the tests
at the user's request; fix them before releasing. The root radius is `(0.60 + 0.16 * scale) * thick` px at the base: `thick` is 5 for the roots (the user asked in steps: a little thicker, "at least twice as thick", "three times thicker now", read as three times the current, then, from a screenshot of the real shell, "a little thinner than that" and "more tapered") and 1 for the faint veins inside the card; the taper is `taper()`, a concave curve to 10% of the base, and the shoots start at 50% of the trunk's radius. **Look at the user's screenshots of the real shell, not only at the preview: the preview made the straight taper look fine and the screenshot showed stubby branches.** Roots are one per 24 px of the card's height on the left (3 to 6) and one per 40 px of its width below (4 to 14); `Tube` is a struct with a `key` (distance from the axis in radii) so overlapping pieces are shaded by the nearer-the-middle one; the shadow offset grows with the radius.

**Realistic roots (2026-10-31, branches `p2/growth-roots-real` then `p2/growth-roots-glow`):** after the tapered tubes the user said they were "still not feeling it, they
need to be more realistic". I changed the material too (opaque bark-coloured roots, alpha = cover) and the user replied "it's fine to be more textured and shaped
realistically but they should still be the glow". **The glow stayed the identity; texture and shape are what was wanted.** Final state in `toastgrowth.frag`: roots are
added light in the toast's colour again (output alpha is only the shadow), with `tube()` taking an arc length and a per-root seed for a rough edge, fibre grain and
mottling, plus `knob()` (necks and knots), `turn()` (heading: sine waves + jitter + a pull towards hanging down), acute shoots (0.62 rad) and swellings at shoot origins.
(The tests were brought up to date before the 0.6.0 release: see "Tests before 0.6.0" below.) Lesson: a request for
"realistic" is not a request to change the look's identity: change form and texture first, and keep the colour and the glow unless told otherwise.

**Tests before 0.6.0 (2026-10-31):** the roots work after 0.5.0 was committed without the tests, at the user's request; before releasing 0.6.0 they were run and
fixed. In `test/growth-test.sh` (30 checks) the alpha-is-zero check became "alpha is only the roots' soft shadow, at most 0.4, and 0 with no roots or far from the card",
and the five countdown-line checks became "the `remaining` value changes nothing" (the picture is byte-identical for remaining 1, 0.5, 0 and none). In
`test/growth-roots-test.sh` (25 checks) the thresholds follow the new design: the roots are about 10 px across at the base so they merge near the card, so the left roots are
counted on a line 40 px out over the whole height (4 to 7 stretches, between 3 and 9 allowed), there are about 7 roots below (at least 5), and the "nothing yet at 4%" check
allows 25 pixels of ink. Five deliberate breaks (no bottom roots, one left root, no stagger, roots stop at 80%, roots shrink back) were all caught. **The ink and activity
measurements (`test/growth-activity.py`) were not redone on the textured, thicker roots**; the pacing was tuned on thin ones.

## P2: the arrival (2026-10-31, **released as 0.7.0 on 2026-11-02**; branch `p2/arrival` here and in the theme repo, merged)

**Direction, from the user (2026-10-31):** the original brief for this work (the notification toasts, even with all the customising, were still cards
on top of the theme's glow and did not align with its size and shape; make toast and glow one visual unit, even if the toast stops being a card)
**applies to the arrival, not to the settled look**; and "it probably makes sense to move the arrival into this project". They chose to **remove the
theme's ring now** and to **remove the settled glow look**. So: the arrival is this repo's, it works with every look, and the theme no longer draws one.

How it got here (so it is not re-derived): ideas were pitched, three mock-ups (`docs/design/glow/`) were rendered over a scene lit by the theme's real
window glow, the user chose "windowed plus the arrival" and it was built as `look=glow` (branch `p2/glow`, still in git history: a toast lit by the window
glow's own colour field, which needed the theme to publish its clock and seed). Judged live, the user then said they cared about the arrival and not the
settled glow. Two live findings from that round are worth keeping: the conf parser took the *first* `look=` line, so `echo look=glow >> file` under an
earlier `look=blend` did nothing and the user saw the blend and said it "doesn't behave as the checklist describes" (the blend's countdown line at the
bottom edge gave it away in the recording; **the last line for a key wins now**, `lastValue` in `Service.qml`); and the theme's depth slider was at 0.65,
five times what the mock-up assumed. Lesson: when a live report says it does not behave as described, check the conf and the recording for which look is
actually on before suspecting the new code.

What it is (`docs/design/arrival/README` section in `docs/design/README.md` has the numbers):
- **One wave per toast, one timeline.** `ArrivalLogic.js` (pure): `p` 0 to 1 over 3.2 / 4.2 / 6 s (low / normal / critical; the theme's old ring's) times
  `motion_slowdown`, `frontAt(p)` the front's radius from the card's centre, `settle` the hand-over, `isFresh` (a toast restored after a shell restart does not arrive).
- `components/ArrivalFlare.qml` (per toast, over the card) owns the toast's clock and the flare overlay (`shaders/toastflare.frag`: the card's edge lit as the
  front crosses it, an afterglow, the icon's spore); the delegate masks the card with `shaders/cardreveal.frag` as a `layer.effect` while `arrival.revealing`;
  `ToastRim` gets `gate` (fades the settled rim in as the front finishes crossing) and `calm` (no ignition flash); `SlotMotion.reveal` opens the slot in 300 ms
  and leaves the card's opacity and scale at 1 on entry. Armed from creation so the card is hidden from the first frame; the clock starts one tick later,
  when layout has given the card its size.
- `components/ArrivalLayer.qml` (one per popup window, under the column, like `SporeLayer`) draws `shaders/toastring.frag`: a ring and a halo that follow **each card's
  own rounded rectangle** (a pixel is reached by the front at `d + |centre - q|`, d its distance from the outline and q the nearest outline point), at most three at a
  time, rendered at half resolution, only while there are any; the window stays visible while it runs (`visible: ... || arrivalLayer.active`, CONTRACT.md). It follows the
  card while it exists (the stack moves).
- **Found live (2026-11-02, from a recording):** the ring was cut off in a straight vertical line as it travelled towards the middle of the screen: the layer was
  sized to the card plus the ring's reach (about 740 px) but the wave travels about 700 px from the *icon*, which is 34 px inside the card, so it ran off the layer's left
  edge. The layer now fills the whole window (half resolution, only while an arrival runs); the probe checks it does. Lesson: size a light's layer from where the light
  can reach (the front's maximum radius from its source), not from the shape it starts from.
- **The exit (2026-11-02, built on request, no mock-up first; the user judges it live):** the arrival played backwards, faster. `SlotMotion.leave()` with `reveal` runs
  `dissolve` 0 to 1 over 1 s (times `motion_slowdown`; the spores are released at 25% of it, when the card starts to come apart), and starts the old fold (300 ms) at 80%, so
  a toast leaves 1.1 s after expiry (CONTRACT.md); `ArrivalFlare` (`exiting`, `q`) retreats the front (`ArrivalLogic.exitFront`: the arrival's wave from `exitStart`, the
  progress at which the front is 15% beyond the card, derived from the geometry because a fixed start left the card part-dissolved at the small ring reach of the probe's window,
  back to 0, less 30 px so nothing remains), the card's mask follows it, `ArrivalLayer.beginExit` runs the ring and halo backwards (an event with `exit: true`), `toastflare.frag`'s
  `reverse` puts the afterglow on the far side with a 60 px trail, and `ToastRim`'s gate fades the rim out. Left-click and the IPC dismissals stay instant; `arrival=0` keeps the old fold.
  Verified: logic (59), shaders (53, incl. 3 exit checks and 2 deliberate breaks), probe (152: ordering of dissolve, spores and fold, the retreating front, the rim gate, the ring told
  and run backwards, the instant paths, `arrival=0`, another theme, slowdown); 10 of 11 QML breaks caught in isolated copies (the survivor: the arrival's clock left running while exiting,
  equivalent, the exit's state takes precedence). **Not verified:** how it looks and feels live (checklist section H, the exit items).
- **Centred (2026-11-02, "try"):** the user asked for the toasts at the top centre of the screen and the arrival centred on the toast. **Position:** `position=center|right` in the fork conf
  (`Service.qml`: `popupWindow.centered`, the column's and the spore layer's `x` replace their right anchors; theme-gated; right is the default and is the stock place). **Origin:** the wave
  now starts at the card's centre, not the icon (`ArrivalFlare.origin`, `toastflare.frag`'s `origin` uniform with a spark there and the icon's ring lit as the front reaches it, `cardreveal.frag`'s
  `origin`, the ring's `src`); the card reach is from the centre. Verified: arrival-test (54), probe (168: position parsing, the column and spore layer centred or right, another theme stock, the
  origin and reach); 6 of 7 wiring breaks caught (the survivor is the reveal mask's own origin binding, which only a live look can see, like the mask itself).
- **Found live (2026-11-02):** on expiry the toast's border faded out more slowly than the arrival collapsed. Cause: the settled rim was faded by its own gate (`settle(front)`, over the front's 110% to 70% of the
  card's reach) while the card kept dissolving until the front reached the centre, so the border lingered round the edges. Now on the way out the gate stays 1 and the ToastRim is a mask layer with the same
  front as the card (`cardreveal.frag` again, in the delegate), so border, halo and the blend's countdown line go exactly as the card does. The probe checks the gate stays 1 and the rim is masked; the rim
  mask's own origin binding is live-only, like the card's.
- **Found live, round two (2026-11-02, from a recording looked at frame by frame at 20 fps, not thumbnails):** after masking the rim, the border *still* lingered a little: a faint outline of the whole rectangle
  stayed for several frames after the card had collapsed to a disc. It was not the rim but the exit flare's afterglow: `exp(-behind / 60)` left 10 to 20% of the edge light at the far ends. The exit's trail is
  now 18 px (the arrival's stays 140); `arrival-test.py` checks it is a smear (lit 12 px beyond the front, nearly gone at 60, none at the far end), and the old lengths fail it. Lesson: look at the
  recording at the frame rate and resolution of the thing, and find the actual lingering element before guessing which layer it is.
- Setting: `arrival` 0 to 2, default 1, in the fork conf; 0 turns the whole arrival off (back to the plain unfold and the blend's ignition).
- **Theme side (branch `p2/arrival` there):** `ArrivalGlow.qml`, `arrival.frag`, `notifyGlow`/`notifyGlowStrength` with their popup slider and switch, the layer rule's
  namespace and the interim `glow.json` writer are removed; the feed, the sound and the missed marks stay. The theme alone has no arrival light now (the user's decision).
- Verified here: `python3 test/arrival-test.py` (47 checks on the three compiled shaders through the harness; 27 of 28 deliberate breaks caught, the survivor is the
  `p <= 0 || p >= 1` guard, redundant with the lives' own zeros); `node test/arrival-logic-test.js` (32); `bash test/service-probe.sh` (126: the real `Service.qml` and
  components: armed and under way early, the card a mask layer and not faded or scaled, the rim gated and calm, over after two seconds, up to three at once, strength
  and `arrival=0`, another theme, a stale toast, critical and slowed durations, the parser incl. last-line-wins); QML wiring breaks: 15 of 18 caught (run in isolated repo copies; a mutation run in the working tree while other checks ran gave flaky results, so do not do that). The survivors: ArrivalLayer's own `strength > 0` guard (redundant: a toast is never armed at 0), and two that only a real screen height can show (the ring reach's 180 px floor hides it in the probe's small window).
  `docs/design/arrival/arrival-mock.py` renders the shipped shaders over the scene.
- **Not verified, needs the user** (checklist section H): how it looks and feels in the real shell (speed, strength, whether the ring reads as the card's shape or
  just a circle, the burst), **the `layer.effect` reveal, which nothing here renders** (Qt's offscreen platform cannot run a ShaderEffect, so only the shaders on Mesa
  and the QML wiring in the probe are checked): a hard or flickering edge on the card's content, text shifting when the layer goes away, the 300 ms slot opening with the
  front; the ring's alignment with real cards of different heights; cost.

## P2: the ring lingers (**released as 0.8.0 on 2026-11-02**; branch `p2/arrival-linger`, merged)

The arrival's ring no longer fades after its few seconds and reappears at the exit: it **rests round the card for the toast's life** and collapses at expiry. The design, the numbers and
the two live findings are in `docs/design/README.md` ("The ring lingers"); what to know here:
- `ArrivalLayer` events are **held** (`hold: true`: they live until replaced or ended, not for `dur`); `heldOf`, `end(item)` (called from `ArrivalFlare`'s destruction, so a click or IPC dismissal
  takes the ring at once) and `beginExit(item, from, start, dur)` (swaps the held event for an exit event; a toast with no ring has nothing to pull in). Three slots in the shader, so the oldest ring
  goes when a fourth arrives. Held rings tick at 30 Hz, frame by frame only while something moves fast (`busy`).
- `toastring.frag`: progress 1 is "arrived" (held), not "over". **The ring is an ellipse centred on the card, sized by `src.z`** (`ArrivalLogic.ringScale(front) = 1 - exp(-front / 110)`; on the way out
  `ringScaleExit`), semi-axes half the card plus 0.55 / 0.8 of `holdReach` (`ArrivalLogic.holdReachFor`: 7% of the screen's height, 48 to 84 px). `ringReach` is now only the front's *timing* (how fast the
  card is revealed), not the ring's size. The ripple is two plane waves in position (an angle-based one pinched into a kink across a wide card). **Live findings (from a recording):** an outline-hugging ring read
  as "card shaped" (an octagon while travelling) and a clamp at the resting distance as "an invisible wall". Lesson: approach a limit, do not clamp to it; do not derive a shape that should look natural from the card's geometry.
- Test lessons: the recording's screen-edge cut and the exit's slot-folding are unchanged; the probe's injected test timers must fire before the probe shell quits (`shell.qml` quits non-spore scenarios at 4.6 s: a timer after that never
  runs and its checks fail with empty values); and an undulation test must measure the ring's half-maximum edge, not its brightest pixel (brightness modulation alone moves that).
- **Not verified:** a critical toast left up for a long time (cost of the 30 Hz tick), the oval at the screen's top edge on other resolutions, more than three toasts.

## Conventions

- Match the surrounding (Omarchy's) QML style in vendored files: terse comments that explain why, no tutorials.
- Shell tools: `set -euo pipefail`, `jq`, no dependencies beyond what Omarchy already requires; exit codes are
  documented at the top of each tool.
- Runbooks say what to run and why, and what each outcome means. Keep them true: update them in the same
  commit as the behaviour they describe.
