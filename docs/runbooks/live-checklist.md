# Live checklist

Run this on a real Omarchy session; the agent that wrote the code cannot (no compositor). It is the
gate for P0, and the regression check for every merge from upstream or feature change after.
Record results in the table at the end and commit it.

## Install, the Omarchy way

```bash
omarchy plugin add https://github.com/TRemigi/omarchy-annihilation-notifications.git --enable --yes
omarchy restart shell
omarchy plugin list | grep annihilation.notifications     # known and enabled
```

`plugin add` clones into `~/.config/omarchy/plugins/annihilation.notifications`, validates the manifest,
and enables it through the shell. Note anything it prints, and whether the restart was needed.
Later, `omarchy plugin update annihilation.notifications` should show the diff and pull a new release:
try it once a second commit exists on `main`.

For development on the fork itself, work in `~/dev/omarchy-annihilation-notifications` and, only then,
link it in (`ln -s ~/dev/omarchy-annihilation-notifications ~/.config/omarchy/plugins/annihilation.notifications`);
`omarchy restart shell` after every edit, because `keepLoaded: true` blocks hot reload, and note that
`omarchy plugin validate` refuses a symlinked folder, so validate the real path. Do not use the link to
test installation.

## A. The takeover

- [ ] `omarchy-shell notifications ping` prints `ok`
- [ ] `busctl --user status org.freedesktop.Notifications` shows one owner (quickshell)
- [ ] `grep -A3 disabledPlugins ~/.config/omarchy/shell.json` lists `omarchy.notifications`
- [ ] `omarchy plugin list` shows the fork enabled and `omarchy.notifications` not
- [ ] no error about `annihilation.notifications` in the shell log (`journalctl --user -b | grep -i annihilation.notifications` or wherever `omarchy-shell` logs)

## B. Behaviour, against stock

- [ ] `notify-send -a Signal "hello" "body"` shows a toast, which expires after about 8 s
- [ ] hovering a toast keeps it; leaving it lets it run out
- [ ] left click runs its action (try a screenshot toast: Super+Alt+, edits it), right click dismisses
- [ ] `notify-send -u critical -a Signal "stay" "until dismissed"` does not expire
- [ ] the bar's Silence Notifications button toggles DND, and the button's state follows
- [ ] with DND on: `notify-send -a Signal "quiet" "x"` shows nothing and appears in history
      (Super+Shift+Alt+,); a bare `notify-send "x"` is dropped; `notify-send -u critical "x"` shows
- [ ] a screenshot (`omarchy-notification-send`, e.g. take a screenshot) shows its toast even with DND on
- [ ] Super+, dismisses the last toast, Super+Shift+, all, Super+Alt+, invokes the last
- [ ] `omarchy restart shell` with a live toast: the toast comes back
- [ ] `ls ~/.local/state/omarchy/notifications/` shows one JSON file per live toast and `history/`
- [ ] the annihilation theme's arrival glow, sound (if on), motes and popup list still work

## C. Fall back, and come back

- [ ] `omarchy plugin disable annihilation.notifications`
- [ ] stock is back: `notify-send -a Signal "stock" "x"` shows a toast; the DND button works;
      `omarchy.notifications` is no longer in `disabledPlugins`
- [ ] note whether `omarchy restart shell` was needed
- [ ] `omarchy plugin enable annihilation.notifications` takes over again
- [ ] (optional) `omarchy plugin remove annihilation.notifications`, check stock, then reinstall

## D. Motion (P2, annihilation theme only)

Needs 0.2.0 or later, which is on `main`: `omarchy plugin update annihilation.notifications` and
`omarchy restart shell`. To test a change that is not on `main` yet (a `p2/...` branch), switch the installed
checkout to it, and go back with `checkout main` and another restart:

```bash
git -C ~/.config/omarchy/plugins/annihilation.notifications fetch origin p2/<branch>
git -C ~/.config/omarchy/plugins/annihilation.notifications checkout p2/<branch>
omarchy restart shell
```

Later commits on the branch: `git -C ... pull origin p2/<branch>` and `omarchy restart shell`. The theme must be
`annihilation`.

**First, make it unmistakable that it is running.** The motion is designed to be subtle, and an earlier
version was so quick (75% done in 80 ms) that it was easy to miss. Slow it down:

```bash
echo 'motion_slowdown=4' > ~/.config/omarchy/annihilation-notifications-fork.conf
notify-send -a Signal "slow motion" "should unfold over about 2 seconds"
```

(The file is re-read when saved; no restart needed for it.) If a toast clearly unfolds and fades in over ~2 s,
the code is live, and you can set it back to `1` or delete the file. If it still appears instantly, the branch
is not what is running: check `git -C ... branch --show-current` and `log -1`, restart the shell, and tell me.

- [ ] a new toast **unfolds** into the top of the stack with a fade, and the toasts already there slide
      down smoothly (no jump, no gap that pops open)
- [ ] a toast that expires **folds away** and the ones under it slide up; nothing snaps
- [ ] right-click dismissing a toast does the same; **clicking** one still acts at once
- [ ] three or four toasts in quick succession (`for i in 1 2 3 4; do notify-send -a Signal "n$i" "body"; done`)
      stack up without flicker or overlap, and leave one at a time without leaving gaps
- [ ] hovering a toast still holds it; moving off lets it run out and fold
- [ ] the gradient border stays crisp (not blurred or cut at the corners) while a card is scaling or folding
- [ ] with DND on, a screenshot toast still appears and folds correctly
- [ ] `omarchy restart shell` with a live toast: it comes back and unfolds without a glitch
- [ ] **switch to another theme** (`omarchy theme set <another>`): toasts appear and vanish instantly again,
      exactly as stock; switch back and the motion returns, without restarting the shell
- [ ] the theme's own effects (arrival glow, sound, missed marks) still behave

When reporting, say what feels wrong: too slow or too quick (entry is 480 ms, exit 300 ms at `motion_slowdown=1`),
the wrong direction, too much scale, or anything that flickers. Those are single numbers in
`components/SlotMotion.qml`, and `motion_slowdown` (0.25 to 8) lets you try other speeds without any code change.

## E. The look (P2 slice 2, annihilation theme only)

Needs 0.3.0 or later, which is on `main` (see D for how to switch to a branch for anything unreleased). Everything here is a first
judgement of taste, so say what you think of each, not just whether it works. The design is in `docs/design/`
(`overview.png`, and `shader-settled.png` / `shader-ignite.png` for the rim as built).

- [ ] a toast has an **iridescent rim**, brightest toward the top right, with a soft glow just inside and a faint
      halo just outside; it is not a flat outline
- [ ] **it ignites**: the rim is brighter for the first moment after a toast arrives and cools to its settled
      strength over about a second, so the arrival ring seems to become the card
- [ ] the **caption** above the title (the app in small Cinzel capitals, "now" at the right) reads well; Omarchy's
      own toasts say OMARCHY, and a plain `notify-send` has no caption
- [ ] the **title** is in Jost with a faint teal glow behind it; the body is lighter; both are easy to read
- [ ] a toast with an **icon** shows a thin ring round it (a ring round app icons that are squares may poke at the
      corners: say if it looks wrong); a toast with a glyph or no icon looks right too
- [ ] a **critical** toast is warm (amber to pink), a **low** one greenish: `notify-send -u critical -a Signal "x" "y"`
      and `-u low`
- [ ] with several toasts, the halos of neighbours do not look like a mess
- [ ] **switch to another theme**: toasts are Omarchy's own, exactly as before, no caption, no rim, Liberation Sans
- [ ] nothing flickers, and the shell does not feel heavier while a toast is up
- [ ] the motion from D still works with the new look

**Section E, the countdown (slice 3, same branch).** A line of light along the bottom edge shows how long a toast has left.

- [ ] a normal toast has a **line along its bottom edge**, **the card's full length when the toast arrives**
      (border to border, with no gap at either end), that shrinks from the right over its 8 seconds, ending in a small bright spark, in the
      colours of the rim (teal into violet)
- [ ] it **freezes while you hover** the toast, and carries on when you move off
- [ ] it fades out in the last moment, and the toast then folds away
- [ ] a **critical** toast has no line (it never expires); a **low** one has a shorter run (5 seconds) in green-blue tones
- [ ] it is not distracting: it should read as part of the rim, not as a progress bar. If it is too bright or too
      prominent, say so (it follows `rim_vividness` too)

Tune without code in `~/.config/omarchy/annihilation-notifications-fork.conf` (re-read when saved):
`rim_vividness=0.4` (0 to 1, default 0.75) for a quieter rim, `rim_vividness=1` for the mock-up's full strength.
Say what looks best and I will change the default.

## F. Spores (P2 slice 4, annihilation theme only; released as 0.4.0)

Needs 0.4.0 or later, which is on `main`. A toast that goes dissolves into spores. Judge the
look, not only that it works; the design is `docs/design/spores-exit.png`.

- [ ] when a toast **expires**, it folds away and a scatter of small glowing spores (amber, and teal for a normal
      toast) lifts off where it was, drifts **to the left**, and fades over about a second and a half
- [ ] when you **right-click** a toast to dismiss it, the same happens
- [ ] when you **click** a toast to act on it (e.g. the screenshot toast), it disappears at once and dissolves into
      spores too
- [ ] a **critical** toast's spores are amber and pink; a **low** one's amber and green
- [ ] the spores are **faint and brief enough** not to be a distraction, and not so faint that you never notice them
- [ ] with several toasts leaving close together, the spores do not turn into a mess
- [ ] the spores never **cover or block** anything you click, and the screen does not flicker when the last toast goes
- [ ] **switch to another theme**: toasts vanish with no spores, as stock
- [ ] `spore_amount=0` in `~/.config/omarchy/annihilation-notifications-fork.conf` turns them off; `0.5` halves them

**The faint drift (slice 4b, same branch).** While a toast is up, a few very faint spores leave its **left edge** now and
then and drift away from it, over several seconds each.

- [ ] you can see them, but only if you look: they are **faint and few** (six at most per toast, each lasting 5 to 8 s)
- [ ] they come off the card's **left edge** and drift left, swaying a little; none appear over the card itself
- [ ] they do not look like dirt or dead pixels on the screen behind the toast (say if they do: it may be too bright
      for a light wallpaper, or too many)
- [ ] `spore_amount` turns them down and off with the same setting as the exit burst

Direction is a design choice to judge: they drift left (away from the screen edge, into free space, never across the
toast below) because a toast in the top-right corner has no room above it, as the first mock-up assumed. Say if you would
rather they went another way.

## G. Growth (P2 slice 6; released as 0.5.0 and refined in 0.6.0, opt-in; annihilation theme only)

Needs 0.6.0 for the items below about the roots and the missing countdown line (0.5.0 had the countdown as the border, lit); both are on `main`; restart the shell after updating.
The new look is **off until you ask for it**: put `look=growth` in `~/.config/omarchy/annihilation-notifications-fork.conf`
(it is read live; `look=blend` or removing the line goes back to the rim of 0.3.0 and 0.4.0). Judge it **against the blend**, by
flipping between the two with the same notifications. The design is `docs/design/growth-settled.png` and `growth-arriving.png`.

- [ ] with `look=growth`, toasts have a **living outline**: its thickness and colour vary slowly along its length, moss
      and teal, and a slow pulse of light travels round it; the outline is **straight**, not wavy
- [ ] **roots** (with side branches) hang from the left edge (about one per 18 px of height, so sparser than before) and the bottom
      edge (one per 20 px), longer than before; those on the left are not denser than those below
- [ ] the growth **eases in** (no pop when a toast arrives), is **fast for most of the growth**, then **slows down hard**, but
      **keeps visibly growing until close to the end of the countdown** (about a quarter of the length after a second, over half
      after two, over four fifths after four, still creeping at six); it does not look linear; roots start a little apart; the last
      finish just before the countdown line does (the growth freezes with the countdown while you hover; an update that restarts
      the countdown does not shrink them; a critical toast, which has no countdown, grows them over about eight seconds)
- [ ] **the second half of a toast's life still shows growth**: after the trunks have slowed, side shoots keep sprouting and
      extending from the roots (the roots get branchier), right up to the end of the countdown line, with nothing that looks
      finished long before it (say if the final look is too bushy, and whether a toast still looks "done" early)
- [ ] they are **long** (left ones up to about 95 px, bottom ones up to about 80 px) and do not look cut off at the end; with
      several toasts at once nothing stutters (the roots are the most expensive part of the shader: say if it does)
- [ ] fainter veins grow across the card from its right corners; none cross onto the toast below. Under a toast with another
      below, the roots from its bottom edge pass **behind** that one, not over it (say if they show on top of it)
- [ ] on the left edge, inside the card, a **scatter of tiny dots (lichen)** in patches, thinning inward and kept clear of
      the icon; some toasts have none, which is intended
- [ ] the icon ring is very slightly irregular (it should read as organic, not as a lumpy circle)
- [ ] **there is no countdown line** with this look: the bottom border is a plain border, and the roots are the timer (they are
      still growing until just before the toast goes)
- [ ] the roots look **organic, not like smooth tubes** but are **still the glow** (the toast's own colour, as light): a rough edge, grain and mottling in
      the glow, knots and swellings, a slight droop, branching at acute angles (say if the texture is too busy or too subtle, or the shape still looks artificial)
- [ ] the roots are **thick at the base** (about five times the first version: about 8 px across), **thinning quickly** and ending in fine points, with slender side shoots (not stubby); fewer of them: about one per 24 px of height on the left, 40 px of width below) and look **3D** and smooth (no visible joins or beading): round tubes with a lit side towards the top right, a highlight and a soft shadow
      down and to the left on the card and the wallpaper (say if they are too thick, the shading is too strong or too weak, or the
      shadow looks dirty)
- [ ] a **critical** toast is ember (amber to rose), a **low** one a dark moss
- [ ] two toasts do not look alike (each has its own seed), and an updated toast keeps its look
- [ ] it does **not** read as dirt, glitches or hair on the card (say which part if it does: the veins, the lichen, the
      outline's thickness), and the text is as readable as with the blend
- [ ] it does not feel heavier than the blend (several toasts at once), and nothing flickers when `look` is changed
- [ ] `look=blend` and a **different theme** are exactly as before (stock off the theme)

Say which you prefer, and what to take from the other: this is the experiment the plan left open.

## H. The arrival and the exit (P2, released as 0.7.0; annihilation theme only)

The arrival moved here from the theme. Needs the theme's change that removes its own ring (the theme's `p2/arrival`, merged to its `main`); otherwise two rings run.
Restart the shell after updating either repo (new files). The setting is `arrival` (0 to 2, default 1; 0 turns it off) in
`~/.config/omarchy/annihilation-notifications-fork.conf` (read live; the last line for a key wins). Slow it down to judge it:
`motion_slowdown=4`, then remove the line. It works with any look. The design is `docs/design/arrival/`.

- [ ] a new toast does **not pop in**: a front of light leaves the **middle of the card** (a spark) and the card is shown only inside it, round, growing outwards to both ends; the icon's ring lights as the front reaches it
- [ ] the card's **edge flares** where the front crosses it and cools behind it; nothing flashes, and the text is never half-drawn in a way that
      looks like a glitch. Look for a hard or flickering edge on the card's content (the card is rendered into a layer while it arrives), text
      that shifts when the arrival ends, and the stack below making room smoothly (300 ms)
- [ ] the front carries on past the card as a **ring and halo that follow the card's outline**: they hug it near the card and round off further out;
      they start from the card's own place (the old ring came from the corner), and do not look like a rectangle clipped at some edge of the screen
- [ ] it still **ends**: after about a second the card is fully there and the settled rim has faded in without a jump; the ring is gone after the
      arrival's few seconds and the toast is exactly the settled one
- [ ] critical toasts are amber to pink, low ones moss, normal ones teal to blue, and they are as strong as the theme's old ring was (say if not)
- [ ] **the exit**: when a toast expires (or you right-click it) it does not fold and fade: a front of light **retreats across the card to the icon**, the card
      dissolving from its far corners into the light, towards the middle; the ring and halo **gather back onto it**; the settled **border goes exactly as the card collapses** (it is taken away by the same front, not faded separately); the spark at the middle goes out last, and the spores
      drift off as the card comes apart; then the stack closes up behind it. About a second. Look for: the card's content edge flickering while the mask retreats, a ring or
      outline that lingers over empty space after the card is gone, the stack closing up late or with a jump, a toast that leaves while another arrives
- [ ] a **left-click** on a toast (it acts and goes) and `omarchy-shell notifications dismissOne` are still instant, as before
- [ ] a **burst** of several toasts at once is not a flash (later ones are fainter, at most three rings at a time)
- [ ] **no second ring**: the theme's own is gone (if you see one from the screen's corner too, the theme is not on `p2/arrival`)
- [ ] a toast restored after `omarchy restart shell` appears at once, with no arrival (**known and accepted:** only a toast more than 3 s old counts as restored, so one sent just before the restart replays its arrival); `notify-send -a Omarchy ...` (an own-action toast) is fainter
- [ ] `arrival=0` is the plain unfold of 0.2 to 0.6; with `look=growth` the roots and rim arrive in step; a **different theme** is exactly as before
- [ ] it does not feel heavy (the ring layer renders at half resolution while an arrival runs, and not at all otherwise)

### H2. The ring lingers (released as 0.8.0)

The arrival's ring no longer fades away: it travels out, **comes to rest a short way from the card (48 to 84 px, 7% of the screen's height) and stays there for the toast's life**,
undulating slowly (a ripple travelling round it, a breath in its brightness and the halo's). On expiry it is pulled in onto the card as the card dissolves into the light
(no more reappearing ring). Critical toasts keep theirs until dismissed. Up to three rings are drawn at once (the oldest of a crowd loses its ring).
Restart the shell after updating (`omarchy restart shell`); a slow `motion_slowdown=3` makes it easiest to judge.
- [ ] the ring is an **oval** round the card (not a copy of its outline), grows out of the card's centre and **eases into its size** (no point where it seems to hit a wall), and stays
- [ ] the ripple is slow and subtle (not distracting, not a pulse); the halo breathes with it
- [ ] on expiry the ring contracts onto the card, brightening, and the card dissolves into it; nothing lingers afterwards
- [ ] a click dismisses the toast and its ring at once
- [ ] with several toasts the rings do not overlap into a mess, and the stack still reads; a toast that arrives fourth takes the oldest ring's place
- [ ] it does not feel heavy while a ring rests (30 Hz updates; the layer renders at half resolution), including a critical toast left up for minutes

## I. The oval toast (P2, branch `p2/oval-body`; annihilation theme, blend look)

The toast is a soft-edged oval under the text, not a card. Restart the shell after syncing; `motion_slowdown=3` makes the arrival easy to watch. `body=card` in the fork's conf file turns it off.
- [ ] (needs the theme's `fix/notification-blur`, then `hyprctl reload`: without it the compositor frosts the backdrop out to a hard edge round the toast) the toast is a **soft-edged rectangle with rounded corners** (an oval before; `shape` in `BodyLogic.js` sets it) with no border or crisp rim: the toast reads as an oval that **dissolves into the glow** over a wide soft edge (about 44 px), with no bright outline round it
- [ ] the ring is **the toast's shape** a steady gap outside it (about 56 px), a soft halo of its own: on a **near-black window**, a **light one** and **over a page of text** behind the toast, the body fades into what is behind it with no outline (the fade is about 80 px, mostly outside the oval), and the ring is clearly separate from it
- [ ] the text has comfortable room from the oval's edge, **including the caption and the "now" at the top corners** and the last line of a three-line body; nothing is cut or sits on the faint edge
- [ ] the arrival: the toast appears as an **oval front** growing from its centre (not a circle cutting it open), **its leading edge soft all round** (no crisp oval line along the top and bottom as it grows) and **no bright outline flashes along its edge** (nor at the start of the exit); the exit takes it away with the card's dissolve
- [ ] with several toasts the ovals overlap only in their soft edges, and a toast still reads clearly over a busy wallpaper
- [ ] the icon's ring is still round the icon, and a critical toast's colours (amber to pink) show on the oval's edge
- [ ] the countdown line is gone (known: it belongs to the card's rectangle); say if you want it back, along the oval
- [ ] `body=card` brings the card back exactly as 0.8.0; `look=growth` is always a card; a different theme is stock
- [ ] a click anywhere on the text works as before; the oval's soft edge beyond the card is not clickable

## Results

| Date | Omarchy | Fork | A | B | C | Notes |
|------|---------|------|---|---|---|-------|
| 2026-11-02 | 4.0.4-1 | 0.7.0-dev = `p2/arrival` @ 0714232 (section H, the arrival) | | | | H: the user confirmed every item except the restore one: a toast on screen at `omarchy restart shell` replays its arrival after the reload (it is under 3 s old, which counts as fresh; accepted, "I don't care aesthetically"). Two live findings on the way: the ring was cut off in a straight line (layer sized to the card; fixed, 0714232) and an earlier conf with `look=blend` above `look=glow` stayed on the blend (last line wins now). Suites at that commit: arrival shaders 47, arrival logic 32, service probe 134, tools 47, logic 35, motion 22, shader 51, spores 21. The exit (0e40b30, the arrival played backwards) was then built without a mock-up at the user's request and judged live: "looking excellent" (no per-item notes). The exit items in section H are unticked individually. |
| 2026-10-31 | 4.0.4-1 | 0.6.0 = `p2/growth-roots-glow` @ 610fb0f (section G, the refined Growth look) | | | | G: the user tried four variants of the roots (glowing thick tubes; solid bark; textured glowing; flat, untextured) and said the textured glowing one was "the best so far" and asked to release it. Per-item notes were not given beyond that. All suites passed on this code (growth 30, roots 25, shader 51, spores 21, motion 22, logic 35, tools 47, service probe 86, validate, check-upstream), after the growth tests were brought up to date; five deliberate breaks of the roots tests were caught. Released as 0.6.0. |
| 2026-10-31 | 4.0.4-1 | 0.5.0 = `p2/growth` @ 231c4d0 (section G, Growth) | | | | G: the user reported "looking good now" after many rounds from screen recordings (countdown aligned on the border, roots denser and longer with a Bezier-then-exponential pace and late shoots, activity tuned to a recording), and asked to release. Per-item notes were not given beyond that. All suites passed on this commit (growth 35, roots 25, shader 51, spores 21, motion 22, logic 35, tools 47, service probe 86, validate, check-upstream). Released as 0.5.0. |
| 2026-10-30 | 4.0.4-1 | 0.4.0 = `p2/spores` @ 2653217 (section F, spores) | | | | F: the user reported "the spores look good" and asked to release. Per-item notes (direction, brightness, the faint drift, the window staying up, clicks) were not given, so only that is recorded. Released as 0.4.0. |
| 2026-10-30 | 4.0.4-1 | 0.3.0 = `p2/look` @ b35037e (section E, the look and the countdown) | | | | E: the user reported "looks good" for the look, and for the countdown after two fixes found from their screenshots (the line was inset 14 px, then stopped at the corners leaving a gap; now border to border). Per-item notes were not given beyond that. Released as 0.3.0. |
| 2026-10-30 | 4.0.4-1 | 0.2.0 = `p2/motion` @ e1d10ef (section D only) | | | | D: all items confirmed by the user ("all of those are good"): the fold, stacking several toasts, hover, border crispness, restart with a live toast, switching theme and back, DND; and the 480/300 ms timing feels right. Seen only after the entry was slowed: the first version (340 ms) was too quick to notice. Released as 0.2.0. |
| 2026-10-30 | 4.0.4-1 | 0.1.0 (`omarchy plugin add` from the pushed repo) | pass | pass | pass | Reported by the user as all items passing; no per-item notes were given, so whether the disable-and-restore needed `omarchy restart shell` is not recorded. Add a row with details next time. |
