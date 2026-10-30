# Falling back to the stock daemon

**Why this matters.** While the fork is enabled, Omarchy's own notifications plugin is switched off. If
the fork fails to load (for instance, an Omarchy update renamed something it imports), there is
**no notification daemon at all**, and the bar's DND button is dead. Always know the way back.

## Mechanism (read from Omarchy 4.0.4's `PluginRegistry.qml`)

Enabling a plugin whose manifest says `omarchy.clonedFrom: "omarchy.notifications"` adds
`omarchy.notifications` to `disabledPlugins[]` in `~/.config/omarchy/shell.json` and records the fork
in `cloneSourceRestores`. Disabling or removing the fork through Omarchy takes the stock plugin out of
`disabledPlugins[]` again. This is verified by reading, and by the live checklist (section C).

## Which command

| Situation | Do |
|-----------|----|
| The fork works but you want stock | `omarchy plugin disable annihilation.notifications`, then `omarchy restart shell` if needed |
| Remove it for good | `omarchy plugin remove annihilation.notifications` |
| No toasts at all, shell is up | the same `disable`; check `journalctl --user -b` for the plugin's load error first if you want to report it |
| The shell UI or `omarchy` commands do not work | break-glass, below |
| After an Omarchy update you want to be safe | `tools/check-upstream`; if it exits 1 or 2, fall back until the fork is updated |

## Break-glass: edit the config by hand

Everything `omarchy plugin disable` does, done by hand, in `~/.config/omarchy/shell.json`:

1. remove the entry with `"id": "annihilation.notifications"` from `plugins[]`
2. remove `"omarchy.notifications"` from `disabledPlugins[]` (delete the key if it is now empty)
3. remove `"annihilation.notifications"` from `cloneSourceRestores` (same)
4. `omarchy restart shell`

Keep the JSON valid (`jq . ~/.config/omarchy/shell.json`). If `omarchy restart shell` is unavailable, log
out and in.

### Do not just delete or rename the plugin folder

The stock plugin would still be listed in `disabledPlugins[]`, so nothing would load, and you would
have *no* daemon. Use the commands above, or the manual edit.

## After falling back

The fork stays installed but disabled. To come back: update it (`omarchy plugin update
annihilation.notifications`), then `omarchy plugin enable annihilation.notifications` and
`omarchy restart shell`, and run the live checklist if Omarchy changed in between.

## Not yet automated

Planned (see `docs/plan.md`, P3): hooks that run `tools/check-upstream` after `omarchy-update` and at
boot and fall back by themselves when a vendored or watched file changed, and a watchdog that falls
back when nothing owns `org.freedesktop.Notifications` shortly after the shell starts.
