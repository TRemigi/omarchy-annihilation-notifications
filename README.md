# omarchy-annihilation-notifications

A themed notification daemon for [Omarchy](https://omarchy.org/), made to go with
omarchy-annihilation-theme. It is a fork of Omarchy's own
notifications plugin, installed as a *registered clone* of it, so the rest of Omarchy (the bar's
Do Not Disturb button, the key bindings, `omarchy-notification-send`) keeps working unchanged, and
**removing or disabling it brings the stock daemon straight back.**

**Status: 0.2.0.** Omarchy 4.0.4's notifications plugin plus the first visible change, **only while the
annihilation theme is active**: toasts unfold into the stack and fold away instead of popping in and out. On any
other theme it behaves exactly as stock. More is planned (a countdown built into the border, spores, accents);
see [docs/plan.md](docs/plan.md). The motion is subtle by design; to exaggerate it, put `motion_slowdown=4` (0.25 to 8) in `~/.config/omarchy/annihilation-notifications-fork.conf`.

0.3.0 also gives the card a new look on the annihilation theme (an iridescent rim that ignites at arrival, a small-caps
caption, Jost and Cinzel, a ring round the icon, and a countdown line along the bottom edge; see
[docs/design](docs/design)). Its setting, in the same file: `rim_vividness` (0 to 1, default 0.75). 0.4.0 adds spores: a toast that goes also
dissolves into a few spores, and a few very faint ones drift off a card's left edge while it is up; `spore_amount` (0 to 1,
default 1) controls both.

0.5.0 added a second look, **Growth**, off until you ask for it: `look=growth` in the same file swaps the rim for a living outline
with lichen, and glowing roots that hang from the card's left and bottom edges and grow over the toast's whole life (`look=blend`,
the default, is the rim above; the file is read live). In 0.6.0 the roots are thicker, tapered and shaded in 3D with a soft shadow and an
organic, textured shape, and the countdown line is gone: with this look the roots are the timer, still growing until just before the
toast goes.

0.7.0 moves the **arrival** here from the theme and makes it one event with the card. A new toast does not pop in: a front of light
leaves the **card's centre** (so the arrival is centred on the toast) and crosses the card, which is shown only inside the front; the card's edge flares as the front crosses it; the front carries
on past the card as a ring and a halo that follow **the card's own outline** (the theme's old ring came from a fixed box near the corner and
never lined up with the card, which is why it was moved). Teal and blue normally, amber and pink for critical, moss for low; the settled rim
(whichever look is chosen) fades in as the arrival's edge light falls. `arrival` (0 to 2, default 1) in the same file sets its strength, 0
turns it off. `position=center` in the same file puts the toast column at the top centre of the screen instead of the top right (`right`, the default, is where Omarchy puts toasts). The theme no longer draws an arrival ring; without this fork there is none.

> ⚠️ Plugins run as unsandboxed code inside `omarchy-shell`, and this one *is* your notification
> daemon. While it is enabled, a bug in it means no notifications. Read the code before enabling it, and
> know the [fallback](#falling-back-to-stock) before you need it.

## What it does and does not change

- It replaces the stock notification daemon **on every theme**, because enabling a clone is not
  per-theme. From P2 on it will look and behave exactly like stock unless the annihilation theme is
  active.
- It keeps the contract other code relies on (IPC target, DND members, state files, layer namespace):
  [CONTRACT.md](CONTRACT.md).
- The annihilation theme works the same without it. Nothing there requires this repo.

## Install

```bash
omarchy plugin add https://github.com/TRemigi/omarchy-annihilation-notifications.git --enable --yes
omarchy restart shell
```

`omarchy plugin add` clones the repo into `~/.config/omarchy/plugins/annihilation.notifications`,
validates it and enables it. It runs without prompts for credentials, so the repo has to be public (or use
the SSH URL `git@github.com:TRemigi/omarchy-annihilation-notifications.git` with a key that needs no
passphrase prompt). Then run [docs/runbooks/live-checklist.md](docs/runbooks/live-checklist.md).

Check that it took over:

```bash
omarchy-shell notifications ping                   # ok
busctl --user status org.freedesktop.Notifications # one owner: quickshell
notify-send -a Signal "hello" "from the fork"
```

## Update

```bash
omarchy plugin update annihilation.notifications   # shows the diff before changing anything
omarchy restart shell
```

Omarchy's own updates can make this fork stale; see [Keeping up with Omarchy](#keeping-up-with-omarchy).

## Falling back to stock

```bash
omarchy plugin disable annihilation.notifications  # stock notifications return
omarchy restart shell                              # if the toast layer does not come back at once
```

`omarchy plugin remove annihilation.notifications` removes the fork altogether. Either way Omarchy
re-enables its own plugin.

**If the shell is unusable**, edit `~/.config/omarchy/shell.json`: take `annihilation.notifications`
out of `plugins[]`, take `omarchy.notifications` out of `disabledPlugins[]`, and take
`annihilation.notifications` out of `cloneSourceRestores`, then `omarchy restart shell`.
**Do not just delete the plugin folder**: the stock plugin would stay listed as disabled and nothing
would run. More in [docs/runbooks/fallback.md](docs/runbooks/fallback.md).

## Keeping up with Omarchy

The fork contains copies of Omarchy's files, so an Omarchy update can leave it behind.

```bash
tools/check-upstream --diff   # has the installed Omarchy changed anything the fork depends on?
tools/import-upstream         # record the installed Omarchy as the new upstream baseline
git merge upstream            # then resolve, test, and release
```

Exit status of `check-upstream`: 0 nothing relevant changed; 1 a vendored file changed (merge needed);
2 only a file the fork depends on changed (review); 3 only the version differs (safe). The full
procedure is in [docs/runbooks/update-from-upstream.md](docs/runbooks/update-from-upstream.md).

If you use the annihilation theme, its `extras/install link` installs hooks that run `check-upstream` after
every `omarchy-update` and at login and switch to the stock daemon by themselves when this fork falls behind
(see [docs/runbooks/fallback.md](docs/runbooks/fallback.md)), and `extras/install notifications
add|update|status|fallback|remove` wraps the install and update.

## Layout

| Path | What |
|------|------|
| `manifest.json`, `Service.qml`, `NotificationLogic.js`, `components/` | the plugin, forked from Omarchy |
| `UPSTREAM` | the Omarchy version and file hashes the fork was last merged against (generated) |
| `reference/omarchy/` | snapshots of the files the fork depends on but does not copy (from `upstream`) |
| `CONTRACT.md` | what must keep working |
| `AGENTS.md` | for an agent or a contributor continuing the work |
| `docs/plan.md`, `docs/runbooks/` | the plan, and procedures |
| `tools/`, `test/` | upstream tracking, and its tests |

Branches: `main` is the fork; `upstream` holds only pristine copies of Omarchy's files, one commit per
Omarchy version, tagged `upstream/<version>`. `git diff upstream main -- Service.qml` is exactly what
this fork changed.

## Licence

MIT, as Omarchy. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
