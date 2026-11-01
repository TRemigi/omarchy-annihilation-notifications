# Releasing

Users receive changes with `omarchy plugin update annihilation.notifications`, which pulls this repo's
default branch. So `main` should only ever hold something that passed the live checklist.

1. Everything is merged and verified (`update-from-upstream.md` step 4).
2. Bump `version` in `manifest.json` (semver: a merge from upstream with no behaviour change is a
   patch; new visible behaviour is a minor).
3. Add a line to `docs/releases.md`: the version, the Omarchy version(s) it was verified against, and
   the date of the live check.
4. Commit, `git tag vX.Y.Z`, push `main`, `upstream` and the tags (`git push origin main upstream --tags`).
   The `upstream` branch has to be pushed: `tools/check-upstream --diff` in a user's clone reads it as
   `origin/upstream`.
5. Nothing to update in the annihilation theme repo for a release: it does not track this repo's versions or status. (If the
   *contract* changed, that is different: see `CONTRACT.md`, and `update-from-upstream.md` step 5.)
