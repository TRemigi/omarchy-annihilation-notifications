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
(renumbered): **1 Motion** (done and released as 0.2.0 on 2026-10-30; the user confirmed all of checklist section D live): toasts unfold into the stack
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

## P2 slice 2: the look (branch `p2/look`, awaiting the user's live check)

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
- Lint baseline now: `Service.qml` 21, `NotificationCard.qml` 14, `ToastRim.qml` 0 (the same classes as before).

## Conventions

- Match the surrounding (Omarchy's) QML style in vendored files: terse comments that explain why, no tutorials.
- Shell tools: `set -euo pipefail`, `jq`, no dependencies beyond what Omarchy already requires; exit codes are
  documented at the top of each tool.
- Runbooks say what to run and why, and what each outcome means. Keep them true: update them in the same
  commit as the behaviour they describe.
