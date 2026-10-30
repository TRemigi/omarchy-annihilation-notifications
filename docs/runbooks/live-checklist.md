# Live checklist

Run this on a real Omarchy session; the agent that wrote the code cannot (no compositor). It is the
gate for P0, and the regression check for every merge from upstream or feature change after.
Record results in the table at the end and commit it.

## Install from a local clone (until the repo is published)

```bash
git clone ~/dev/omarchy-annihilation-notifications ~/.config/omarchy/plugins/annihilation.notifications
omarchy-shell shell rescanPlugins
omarchy plugin list | grep annihilation.notifications     # known, disabled
omarchy plugin enable annihilation.notifications
omarchy restart shell
```

For day-to-day development use a symlink instead
(`ln -s ~/dev/omarchy-annihilation-notifications ~/.config/omarchy/plugins/annihilation.notifications`)
and `omarchy restart shell` after every edit: `keepLoaded: true` blocks hot reload.
`omarchy plugin validate` refuses a symlinked folder; validate the real path.

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

## Results

| Date | Omarchy | Fork | A | B | C | Notes |
|------|---------|------|---|---|---|-------|
|      |         |      |   |   |   |       |
