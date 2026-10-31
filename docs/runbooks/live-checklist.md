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

Needs the `p2/motion` branch until it is merged. Switch the installed checkout to it:

```bash
git -C ~/.config/omarchy/plugins/annihilation.notifications fetch origin p2/motion
git -C ~/.config/omarchy/plugins/annihilation.notifications checkout p2/motion
omarchy restart shell
```

(If the checkout complains about unrelated histories, the install predates the one-time history rewrite:
`extras/install notifications remove` then `add` in the theme repo, then the commands above.)
Go back with `git -C ... checkout main` and another restart. The theme must be `annihilation`.
To pick up later commits on the branch: `git -C ... pull origin p2/motion` and `omarchy restart shell`.

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

## Results

| Date | Omarchy | Fork | A | B | C | Notes |
|------|---------|------|---|---|---|-------|
| 2026-10-30 | 4.0.4-1 | `p2/motion` @ e1d10ef (section D only) | | | | D: the user reports the fold works as expected, seen after the entry was slowed (the first version, 340 ms, was too quick to notice). The other D items (stacking several toasts, hover, border crispness, restart with a live toast, theme switch back to stock, DND) were not itemised: still to confirm before merging to `main`. |
| 2026-10-30 | 4.0.4-1 | 0.1.0 (`omarchy plugin add` from the pushed repo) | pass | pass | pass | Reported by the user as all items passing; no per-item notes were given, so whether the disable-and-restore needed `omarchy restart shell` is not recorded. Add a row with details next time. |
