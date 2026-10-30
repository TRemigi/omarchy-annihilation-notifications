#!/bin/bash
# Shared by the tools in this directory. Sourced, not run.
#
# What "upstream" means here: the files of the installed Omarchy (OMARCHY_ROOT, default
# /usr/share/omarchy). Two kinds are tracked, and both are snapshotted the same way:
#
#   vendored  every file of Omarchy's own notifications plugin (shell/plugins/notifications).
#             They are copied to the root of this repo and edited there; the pristine copies
#             live on the `upstream` branch.
#   watched   files this fork does not copy but depends on: shared QML, the callers of the
#             daemon, the clone machinery. They are stored on the `upstream` branch under
#             reference/omarchy/ so a change can be read as a diff.
#
# A hash tells you a file changed, not that the fork broke. It is a tripwire.

FORK_ROOT=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
OMARCHY_ROOT=${OMARCHY_ROOT:-/usr/share/omarchy}
PLUGIN_SRC=shell/plugins/notifications
REFERENCE_DIR=reference/omarchy

# One entry per line.   path                  the whole file
#                       path::REGEX           only the lines matching REGEX (grep -E), kept without
#                                             line numbers so unrelated edits do not show
#                       dir::list:REGEX       the sorted names of files under dir that match REGEX
WATCHED=(
  "shell/Commons/qmldir"
  "shell/Commons/Style.qml"
  "shell/Commons/Color.qml"
  "shell/Commons/Border.qml"
  "shell/Commons/BorderGeometry.js"
  "shell/Commons/Util.qml"
  "shell/Ui/qmldir"
  "shell/Ui/BorderSurface.qml"
  "shell/services/PluginFirstPartyServiceApi.qml"
  "shell/plugins/bar/indicators/Dnd.qml"
  "bin/omarchy-notification-send"
  "bin/omarchy-notification-dismiss"
  "bin/omarchy-notification-wait"
  "bin/omarchy-notification-battery"
  "bin/omarchy-notification-time"
  "bin/omarchy-notification-weather"
  "bin/omarchy-toggle-notification-silencing"
  "default/hypr/bindings/utilities.lua::notifications"
  "shell/shell.qml::omarchy\\.notifications|firstPartyServiceFor"
  "shell/services/PluginRegistry.qml::clonedFrom|resolveEnabledId|cloneSourceRestores|restoreCloneSource|disabledPlugins"
  "migrations::list:-i notification"
)

die() { echo "$(basename "$0"): $*" >&2; exit 64; }

need() {
  local c
  for c in "$@"; do command -v "$c" >/dev/null || die "needs $c"; done
}

# The installed Omarchy's version: the package version when OMARCHY_ROOT is the real install,
# otherwise OMARCHY_VERSION or the root's own `version` file.
omarchy_version() {
  local v
  if [[ -n ${OMARCHY_VERSION:-} ]]; then echo "$OMARCHY_VERSION"; return; fi
  if [[ $OMARCHY_ROOT == /usr/share/omarchy ]] && v=$(pacman -Q omarchy 2>/dev/null); then echo "${v#* }"; return; fi
  if [[ -f $OMARCHY_ROOT/version ]]; then head -n1 "$OMARCHY_ROOT/version"; else echo unknown; fi
}

# snapshot DEST: the vendored files at DEST/ and the watched ones under DEST/reference/omarchy/.
snapshot() {
  local dest=$1 root=$OMARCHY_ROOT entry path rest out
  [[ -d $root/$PLUGIN_SRC ]] || die "no $PLUGIN_SRC under $root (set OMARCHY_ROOT?)"
  mkdir -p "$dest"
  (cd "$root/$PLUGIN_SRC" && find . -type f -print0 | xargs -0 -r cp -L --parents -t "$dest")

  for entry in "${WATCHED[@]}"; do
    path=${entry%%::*}
    out=$dest/$REFERENCE_DIR/$path
    if [[ $entry != *::* ]]; then
      [[ -f $root/$path ]] || continue
      mkdir -p "$(dirname "$out")"
      cp -L "$root/$path" "$out"
      continue
    fi
    rest=${entry#*::}
    if [[ $rest == list:* ]]; then
      [[ -d $root/$path ]] || continue
      mkdir -p "$(dirname "$out")"
      # shellcheck disable=SC2086  # the pattern may carry a flag, as in "-i notification"
      (cd "$root/$path" && grep -rlE ${rest#list:} . 2>/dev/null | sed 's|^\./||' | LC_ALL=C sort) >"$out.list" || true
    else
      [[ -f $root/$path ]] || continue
      mkdir -p "$(dirname "$out")"
      grep -E -- "$rest" "$root/$path" >"$out.excerpt" || true
    fi
  done
}

# hash_tree DIR: "sha256  relative/path" for every file under DIR except UPSTREAM and .git, sorted by path.
hash_tree() {
  (cd "$1" && find . -path ./.git -prune -o -type f ! -name UPSTREAM -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum | sed 's|  \./|  |')
}

# hashes_json: the lines from hash_tree on stdin as {"path": "sha256", ...}.
hashes_json() {
  jq -Rn '[inputs | capture("^(?<h>[0-9a-f]+)  (?<p>.*)$")] | map({(.p): .h}) | add // {}'
}

# The git ref that holds the pristine upstream files: the local branch, or a clone's remote one.
upstream_ref() {
  local r
  for r in upstream origin/upstream; do
    if git -C "$FORK_ROOT" rev-parse --verify -q "$r^{commit}" >/dev/null; then echo "$r"; return; fi
  done
  return 1
}
