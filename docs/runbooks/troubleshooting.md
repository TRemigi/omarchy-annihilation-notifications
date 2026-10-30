# Troubleshooting

| Symptom | Likely cause | Try |
|---------|--------------|-----|
| `omarchy plugin list` does not show it after install | the shell has not rescanned | `omarchy-shell shell rescanPlugins`, then `omarchy restart shell` (new files need the restart) |
| Enabled, but no toasts | the QML failed to load, and the stock plugin is switched off | `fallback.md`; `journalctl --user -b | grep -i annihilation` for the error |
| Toasts, but the DND button does nothing | `doNotDisturb` / `setDoNotDisturb` no longer exposed, or the clone is not enabled | `CONTRACT.md`; `omarchy-shell notifications dndState` |
| Two daemons / "name already taken" | the stock plugin was not switched off | check `disabledPlugins` in `shell.json`; `fallback.md` break-glass step 2 in reverse; `omarchy restart shell` |
| My edit has no effect | `keepLoaded: true` blocks hot reload | `omarchy restart shell` |
| `omarchy plugin validate` complains about a symlink | it refuses symlinked folders | validate the real path |
| `tools/check-upstream` says no UPSTREAM | `upstream` not merged yet | `git merge upstream` (first time: `--allow-unrelated-histories`) |
| `tools/check-upstream --diff` shows no diffs in a clone | `origin/upstream` not fetched | `git fetch origin upstream` |
| `tools/import-upstream` cannot tell the version | `pacman -Q omarchy` failed | `--version <v>` |
