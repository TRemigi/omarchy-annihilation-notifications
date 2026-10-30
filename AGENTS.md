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

Phases (details in `docs/plan.md`): **P0** functional parity (done, awaiting the live checklist);
**P1** tooling, runbooks, fallback (partly done); **P2** the actual experience, theme-gated; **P3** integration
with the theme's plugin, automatic fallback, CI. **Do not start P2 until the live checklist has passed on a
real session.** Parity first is the whole point: it proves install, update and fallback on a fork that
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
omarchy plugin validate .
tools/check-upstream             # exit 0 when the installed Omarchy matches the baseline
T=$(mktemp -d); ln -s /usr/share/omarchy/shell "$T/qs"
/usr/lib/qt6/bin/qmllint -I "$T" -I /usr/lib/qt6/qml Service.qml components/NotificationCard.qml
```

qmllint baseline on Omarchy 4.0.4-1 (identical to stock, because the code is): `Service.qml` 15 warnings
(unqualified access x10, `PanelWindow` not creatable, `QProcess::ExitStatus` not found x2, `sizeVertical` /
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

**Not verified, needs the user:** that the fork loads and behaves as stock inside a real shell; that
disabling it really restores the stock plugin (and whether `omarchy restart shell` is needed); the D-Bus
hand-over; DND and `omarchy-notification-send` through the clone. All in the live checklist.

Decisions already made with the user: a separate repo registered as a clone (not a patch); parity first;
the fork behaves as stock off the annihilation theme (no theme-switch daemon swapping); track packaged
Omarchy releases only, not the dev/edge channels; **automatic fallback on by default** (P3). Still open:
whether the repo is public. The owner is **TRemigi**
(`git@github.com:TRemigi/omarchy-annihilation-notifications.git`, the same SSH convention as the theme repo),
and `origin` is configured locally, but **nothing has been pushed**: the agent's sandbox could not create
the repo or push (`gh` token invalid, no DNS for SSH). The user pushes; see "First push" below.

Open items, in order: the live checklist (user); `tools/contract-check`, `tools/status`, a `fallback`
tool and CI (P1); then this repo's counterpart in the theme repo (`extras/install notifications ...`,
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

## Conventions

- Match the surrounding (Omarchy's) QML style in vendored files: terse comments that explain why, no tutorials.
- Shell tools: `set -euo pipefail`, `jq`, no dependencies beyond what Omarchy already requires; exit codes are
  documented at the top of each tool.
- Runbooks say what to run and why, and what each outcome means. Keep them true: update them in the same
  commit as the behaviour they describe.
