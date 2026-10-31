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

Needs the `p2/look` branch until it is merged (see D for how to switch to a branch). Everything here is a first
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

## Results

| Date | Omarchy | Fork | A | B | C | Notes |
|------|---------|------|---|---|---|-------|
| 2026-10-30 | 4.0.4-1 | 0.2.0 = `p2/motion` @ e1d10ef (section D only) | | | | D: all items confirmed by the user ("all of those are good"): the fold, stacking several toasts, hover, border crispness, restart with a live toast, switching theme and back, DND; and the 480/300 ms timing feels right. Seen only after the entry was slowed: the first version (340 ms) was too quick to notice. Released as 0.2.0. |
| 2026-10-30 | 4.0.4-1 | 0.1.0 (`omarchy plugin add` from the pushed repo) | pass | pass | pass | Reported by the user as all items passing; no per-item notes were given, so whether the disable-and-restore needed `omarchy restart shell` is not recorded. Add a row with details next time. |
