# The theme repo's side: installer, guard and hooks

This fork is installed and looked after, optionally, by the **omarchy-annihilation-theme** repo
(`github.com/TRemigi/omarchy-annihilation-theme`, checked out at `~/dev/omarchy-annihilation-theme`). The code for that lives
*there*, because it is part of the theme's installer; the design of it is written down *here*, because it exists to serve this
fork and has to change when the fork's tooling changes. (It used to live in the theme repo's `AGENTS.md` and in a mirrored
copy of `docs/plan.md` there, which had to be kept in step by hand; both are gone. This repo is now the only home of the
notification fork's plan and design. The theme repo keeps only its own code, its README's user-facing install instructions, and
pointers here.)

The theme works the same without the fork, and the fork works without the theme (installed by hand with `omarchy plugin add`);
none of what is below runs unless both are present. The theme's shimmer plugin is **not** changed to require the fork.

## What the theme repo has

| Where (in the theme repo) | What |
|---|---|
| `extras/notifications-fork` | the controller: `status`, `add`, `update`, `enable`, `fallback`, `remove`, `auto`, `guard` |
| `extras/install notifications <command>` | a wrapper that runs the controller; `extras/install status` has a line for the fork |
| `extras/hooks/post-update.sh`, `post-boot.sh` | the guard's hooks, linked by `extras/install link` and unlinked by `unlink` (like `theme-set.sh`); inert unless the fork is installed and enabled; always exit 0 |
| `extras/dev/notifications-fork-test.sh` | tests the controller, the guard and the installer's hooks against fake `omarchy`, `omarchy-shell` and `busctl` that emulate the registry's `shell.json` edits (141 checks, 22 deliberate breaks caught) |
| README, "Notification fork (optional)" | the user-facing instructions: the commands below, the warning that plugins run unsandboxed, and where the manual fallback is |
| `docs/notifications.md` | the notification features the *theme's* plugin has (the feed, arrival glow, sound, missed marks on the bar). They read this daemon's state files (see `CONTRACT.md`), which is why changing those files means telling the theme repo |

The user-facing commands:

    extras/install notifications add        # install it with `omarchy plugin add`; enables it only if it is in step
    extras/install notifications status     # installed? enabled? in step with your Omarchy? who owns the D-Bus name?
    extras/install notifications update     # pull the latest; come back from an automatic fallback
    extras/install notifications fallback   # use the stock daemon now (the fork stays installed)
    extras/install notifications enable     # switch it back on (refuses while it is out of step; --force overrides)
    extras/install notifications remove     # uninstall it; stock returns
    extras/install notifications auto off   # only tell me; do not fall back by yourself (default: on)

After `add` or `enable`, `omarchy restart shell`. The fork's URL is one constant in the controller script.

## How the guard works

So that it is not re-derived. The fork vendors Omarchy's plugin, so an Omarchy update can leave it broken, and while the fork is
enabled the stock plugin is off: a fork that fails to load means *no notification daemon*. This repo's `tools/check-upstream
--quiet` (run from the installed plugin dir) exits 0 or 3 when the installed Omarchy still matches what the fork was merged
against, 1 or 2 when it does not, and anything else means it could not tell.

`guard` runs after `omarchy-update` (the `post-update` hook) and at login (the `post-boot` hook, which also covers plain `pacman`
updates). If the fork is enabled (read from `shell.json`: it is enabled exactly when its id is in `plugins[]`, as a string or an
`{id}` object) and the check exits 1 or 2, it:

1. runs `omarchy plugin disable annihilation.notifications`;
2. waits until `shell.json` shows the fork off **and** `omarchy.notifications` out of `disabledPlugins[]` (the second is the one that
   matters: it is what shows the registry has restored the stock daemon);
3. writes `~/.local/state/annihilation-theme/notifications-fork-held` (`kind=auto`), and notifies once stock is back.

It never edits `shell.json` itself, never acts when the check could not run (not being able to check is not a reason to switch), and
always exits 0. Its log is `~/.local/state/annihilation-theme/notifications-fork.log`.

`update` brings back an *auto* hold once the check passes; a *manual* hold (from `fallback`) stays until `enable`. `auto off` (a
line in `~/.config/omarchy/annihilation-notifications.conf`, the theme's file, not this repo's `annihilation-notifications-fork.conf`)
makes the guard tell instead of acting. `enable` refuses while the fork is out of step with the installed Omarchy (`--force`
overrides).

**Status of the guard:** tested with the fakes above; **not yet seen on a real Omarchy update or boot**, because that needs a real
Omarchy update. The manual fix, if the commands do not work, is `docs/runbooks/fallback.md`: `omarchy plugin disable
annihilation.notifications`, or edit `~/.config/omarchy/shell.json` by hand. Do not delete or rename the plugin folder.

## One thing found on the real machine

The user installed the fork before its git history was rewritten (to remove an email address), so their checkout is on the old
commits and `omarchy plugin update` fails with "cannot fast-forward". `extras/install notifications update` says to `remove` then
`add`.

## The original design (P1), for reference

Written before the code; the code differs in that the controller is `extras/notifications-fork` and has `enable` and `auto on|off`
as well, and the fork's own `status`/`fallback` tools in this repo are separate and still to do.

- `extras/install notifications <add|update|status|fallback|remove>`: thin wrappers over `omarchy plugin add/update/disable/remove`
  that add what the plain commands do not: refuse if the shell is not running, run `check-upstream` before enabling and after
  updating, print the Omarchy version against the fork's baseline, say who owns the D-Bus name now, and clear or set the held marker.
- Hooks `post-update.sh` and `post-boot.sh`, always exiting 0, doing nothing unless the fork is installed.
- A README section: what it adds, that it replaces the stock daemon on every theme though it behaves as stock off the annihilation
  theme, that plugins run unsandboxed (the warning `omarchy plugin add` itself prints), how to get it, update it, fall back and
  remove it, and that the theme works the same without it.
- The shimmer plugin and the theme are **not** changed to require the fork.

- **The glow state (optional, for `look=glow`).** The theme's shimmer plugin publishes `~/.local/state/annihilation-theme/glow.json` (its
  window glow's clock, seed, intensity and depth); the fork reads it so a toast is lit by the same light as the windows. See
  CONTRACT.md. The fork works without it; the theme does not read anything back.
