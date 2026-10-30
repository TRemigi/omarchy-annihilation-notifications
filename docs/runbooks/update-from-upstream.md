# Updating from Omarchy

Omarchy ships as a pacman package and changes whenever it likes. This fork vendors a copy of its
notifications plugin, so every Omarchy release is one of: nothing to do, a review, or a merge.

## 1. Find out

```bash
tools/check-upstream --diff
```

It compares the **installed** Omarchy (`/usr/share/omarchy`; `OMARCHY_ROOT=<dir>` for another tree)
with `UPSTREAM`, using file hashes, so it judges what is on this disk, not a version number.

| Exit | Meaning | Do |
|------|---------|----|
| 0 | nothing the fork depends on changed | nothing |
| 3 | only the version differs | step 2 and 3, then fast-forward; release note only |
| 2 | a *watched* file changed (shared QML, a caller, the clone machinery) | read the diff (step 1a), then step 2 even if the fork needs no change, so the baseline moves |
| 1 | a *vendored* file changed, was added or removed | the full procedure |
| 64 | the tool could not run | read its message; usually `UPSTREAM` missing (merge `upstream`) or no Omarchy at that path |

**1a. Reading a watched-file diff.** The question is always "does a caller or dependency of the
fork behave differently". Look for: a renamed or removed member of `Style`, `Color`, `Border`,
`Util`, `BorderSurface`; a changed `firstPartyServiceFor` / the allow-list in `shell.qml`; a change in
`PluginRegistry.qml` to `clonedFrom`, `resolveEnabledId`, `cloneSourceRestores` or `disabledPlugins`
(this is the mechanism the whole fork rides on: treat any change as serious); a different
`omarchy-shell notifications ...` call in a binding or script (compare with `CONTRACT.md`); new
hints in `omarchy-notification-send`; a migration that mentions notifications.

## 2. Import the new baseline

```bash
tools/import-upstream            # the installed Omarchy; --from DIR for another tree
```

It commits the pristine files and a new `UPSTREAM` to the `upstream` branch (never your checkout) and
tags `upstream/<version>`. Running it again for the same baseline does nothing.

## 3. Merge

```bash
git checkout -b merge/omarchy-<version> main
git merge upstream
```

Conflicts are expected in the vendored files. How to resolve:

- **`UPSTREAM` and `reference/`**: always take upstream's. They are only ever edited on `upstream`
  (`git checkout --theirs UPSTREAM reference && git add UPSTREAM reference`).
- **A vendored file**: keep upstream's new code and re-apply our change on top. Our changes are marked
  with `// annihilation:` or live in files of our own, precisely so that you can find them; if a
  conflict hunk has no marker, it is upstream's. Do not take "ours" wholesale.
- If a change of ours no longer makes sense after upstream's, rework it rather than forcing it in, and
  note why in the commit.
- If it is hopeless, `git merge --abort`. The fork is then *held*: users stay safe on stock (see
  `fallback.md`) until it catches up. Nothing else is needed.

## 4. Verify

```bash
bash test/tools-test.sh                 # the tools
node test/logic-test.js                 # NotificationLogic.js
omarchy plugin validate .               # from the repo root, not through a symlink
# QML against the installed shared code, as the theme repo's AGENTS.md describes:
T=$(mktemp -d); ln -s /usr/share/omarchy/shell "$T/qs"
/usr/lib/qt6/bin/qmllint -I "$T" -I /usr/lib/qt6/qml Service.qml components/NotificationCard.qml
```

Compare the qmllint output with the baseline noise recorded in `AGENTS.md`; new warnings about
members not found on `Style`/`Color`/`Border` mean an API moved. Then run `docs/runbooks/live-checklist.md`
on a real session. Merges are not done until that passes.

## 5. Release

See `release.md`. Then tell the annihilation theme repo if the state-file format, the lifetimes, the
DND rules or the layer namespace moved: it reads the state files and mirrors the lifetimes.
