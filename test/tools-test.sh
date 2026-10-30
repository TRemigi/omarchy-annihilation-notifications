#!/bin/bash
# Tests for tools/import-upstream and tools/check-upstream, run against a scratch copy of the
# installed Omarchy and a scratch copy of this repo, so nothing real is touched.
#
#   test/tools-test.sh [path/to/an/omarchy/tree]      default: /usr/share/omarchy
#
# Each check was also confirmed to fail when the code under test was broken on purpose.
set -uo pipefail

HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
SRC=${1:-/usr/share/omarchy}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

pass=0 fail=0
check() { # check NAME WANT GOT
  if [[ $2 == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: want [$2] got [$3]"; fi
}
status_of() { "$@" >/dev/null 2>&1; echo $?; }

# A fake Omarchy: only the directories the tools look at.
fake=$tmp/omarchy
mkdir -p "$fake/default"
cp -a "$SRC/shell" "$SRC/bin" "$SRC/migrations" "$fake/" 2>/dev/null
cp -a "$SRC/default/hypr" "$fake/default/"
echo "9.9.9-1" >"$fake/version"

# A fake fork: this repo's tools, committed, nothing else.
repo=$tmp/fork
mkdir -p "$repo" && cd "$repo" || exit 1
git init -q -b main . && git config user.name t && git config user.email t@t
cp -a "$HERE/tools" . && git add -A && git commit -q -m tools
export OMARCHY_ROOT=$fake OMARCHY_VERSION=9.9.9-1

check "check refuses to run before the first import" 64 "$(status_of tools/check-upstream)"

out=$(tools/import-upstream 2>&1); check "first import succeeds" 0 "$?"
check "first import says to merge unrelated histories" 1 "$(grep -c 'allow-unrelated-histories' <<<"$out")"
check "the upstream branch exists" 1 "$(git branch --list upstream | wc -l | tr -d ' ')"
check "it is tagged upstream/9.9.9-1" "upstream/9.9.9-1" "$(git tag --list 'upstream/*')"
check "the branch holds the vendored files and UPSTREAM" "NotificationLogic.js Service.qml UPSTREAM" \
  "$(git ls-tree --name-only upstream | grep -v -e manifest.json -e components -e reference | tr '\n' ' ' | sed 's/ $//')"
check "and the watched ones" 1 "$(git ls-tree -r --name-only upstream | grep -c '^reference/omarchy/shell/Commons/Style.qml$')"
check "UPSTREAM records the version" "9.9.9-1" "$(git show upstream:UPSTREAM | jq -r .omarchyVersion)"
check "the worktree was cleaned up" 1 "$(git worktree list | wc -l | tr -d ' ')"

git merge -q --allow-unrelated-histories upstream -m "merge upstream" >/dev/null 2>&1
check "the merge brought UPSTREAM to main" 1 "$([[ -f UPSTREAM ]] && echo 1 || echo 0)"

check "unchanged: exit 0" 0 "$(status_of tools/check-upstream)"
check "--quiet prints nothing" 0 "$(tools/check-upstream --quiet 2>&1 | wc -l | tr -d ' ')"

n=$(git rev-list --count upstream)
out=$(tools/import-upstream 2>&1); rc=$?
check "importing the same baseline again succeeds" 0 "$rc"
check "importing the same baseline again commits nothing" "$n" "$(git rev-list --count upstream)"
check "and says so" 1 "$(grep -c 'nothing to commit' <<<"$out")"

# A vendored file changes.
echo "// upstream edit" >>"$fake/shell/plugins/notifications/Service.qml"
check "a vendored file changed: exit 1" 1 "$(status_of tools/check-upstream)"
out=$(tools/check-upstream 2>&1 || true)
check "it names the file" 1 "$(grep -c 'changed Service.qml' <<<"$out")"
out=$(tools/check-upstream --diff 2>&1 || true)
check "--diff shows the added line" 1 "$(grep -c '^+// upstream edit' <<<"$out")"
sed -i '$d' "$fake/shell/plugins/notifications/Service.qml"
check "reverting it: exit 0" 0 "$(status_of tools/check-upstream)"

# A file appears in, and one disappears from, the plugin directory.
touch "$fake/shell/plugins/notifications/New.qml"
check "a new vendored file: exit 1" 1 "$(status_of tools/check-upstream)"
check "and it is called added" 1 "$(tools/check-upstream 2>&1 | grep -c 'added New.qml')"
rm "$fake/shell/plugins/notifications/New.qml"
mv "$fake/shell/plugins/notifications/NotificationLogic.js" "$tmp/NL.js"
check "a removed vendored file: exit 1" 1 "$(status_of tools/check-upstream)"
check "and it is called removed" 1 "$(tools/check-upstream 2>&1 | grep -c 'removed NotificationLogic.js')"
mv "$tmp/NL.js" "$fake/shell/plugins/notifications/NotificationLogic.js"
check "restored: exit 0" 0 "$(status_of tools/check-upstream)"

# A vendored and a watched file change together: the vendored one decides.
echo "// a" >>"$fake/shell/plugins/notifications/Service.qml"; echo "// b" >>"$fake/shell/Commons/Style.qml"
check "both changed: exit 1, not 2" 1 "$(status_of tools/check-upstream)"
sed -i '$d' "$fake/shell/plugins/notifications/Service.qml"; sed -i '$d' "$fake/shell/Commons/Style.qml"
check "both reverted: exit 0" 0 "$(status_of tools/check-upstream)"

# A watched file changes.
echo "// shared edit" >>"$fake/shell/Commons/Style.qml"
check "a watched file changed: exit 2" 2 "$(status_of tools/check-upstream)"
check "it is listed under watched" 1 "$(tools/check-upstream 2>&1 | grep -c 'reference/omarchy/shell/Commons/Style.qml')"
sed -i '$d' "$fake/shell/Commons/Style.qml"

# Excerpts: only the matching lines count.
echo "// nothing about the service here" >>"$fake/shell/shell.qml"
check "an unrelated edit to shell.qml: exit 0" 0 "$(status_of tools/check-upstream)"
sed -i '$d' "$fake/shell/shell.qml"
sed -i '1i // a line added at the top moves every line number' "$fake/shell/shell.qml"
check "lines moving down in shell.qml change nothing: exit 0" 0 "$(status_of tools/check-upstream)"
sed -i '1d' "$fake/shell/shell.qml"
echo "// nothing about the service here" >>"$fake/shell/shell.qml"
echo "    var x = shell.firstPartyServiceFor(\"x\")" >>"$fake/shell/shell.qml"
check "a new firstPartyServiceFor line: exit 2" 2 "$(status_of tools/check-upstream)"
sed -i '$d' "$fake/shell/shell.qml"; sed -i '$d' "$fake/shell/shell.qml"
check "reverted: exit 0" 0 "$(status_of tools/check-upstream)"

# Lists: a migration that mentions notifications.
echo "notify the user about a notification" >"$fake/migrations/9999999999.sh"
check "a new migration that mentions notifications: exit 2" 2 "$(status_of tools/check-upstream)"
echo "nothing relevant" >"$fake/migrations/9999999999.sh"
check "one that does not: exit 0" 0 "$(status_of tools/check-upstream)"
rm "$fake/migrations/9999999999.sh"

# Only the version changes.
export OMARCHY_VERSION=9.9.10-1
check "version only: exit 3" 3 "$(status_of tools/check-upstream)"
tools/import-upstream >/dev/null 2>&1; check "re-importing records it" 0 "$?"
check "tagged upstream/9.9.10-1" 1 "$(git tag --list 'upstream/9.9.10-1' | wc -l | tr -d ' ')"
git merge -q upstream -m "merge upstream" >/dev/null 2>&1
check "after the merge: exit 0" 0 "$(status_of tools/check-upstream)"

# A real change imported and merged.
echo "// upstream edit two" >>"$fake/shell/plugins/notifications/Service.qml"; export OMARCHY_VERSION=9.9.11-1
tools/import-upstream >/dev/null 2>&1
check "the upstream commit has the change" 1 "$(git show upstream:Service.qml | grep -c 'upstream edit two')"
git merge -q upstream -m "merge upstream" >/dev/null 2>&1
check "main picked it up" 1 "$(grep -c 'upstream edit two' Service.qml)"
check "and the check is clean again" 0 "$(status_of tools/check-upstream)"

# A file upstream deleted is deleted from the upstream branch too.
echo "// temp" >"$fake/shell/plugins/notifications/Temp.qml"; export OMARCHY_VERSION=9.9.12-1
tools/import-upstream >/dev/null 2>&1
check "an added upstream file is imported" 1 "$(git ls-tree --name-only upstream | grep -c '^Temp.qml$')"
rm "$fake/shell/plugins/notifications/Temp.qml"; export OMARCHY_VERSION=9.9.13-1
tools/import-upstream >/dev/null 2>&1
check "and is gone after upstream removes it" 0 "$(git ls-tree --name-only upstream | grep -c '^Temp.qml$')"
git merge -q upstream -m m >/dev/null 2>&1
check "after merging, the check is clean" 0 "$(status_of tools/check-upstream)"
export OMARCHY_VERSION=9.9.11-1

# A tag clash gets a suffix instead of failing.
echo "// upstream edit three" >>"$fake/shell/plugins/notifications/Service.qml"
tools/import-upstream >/dev/null 2>&1
check "a same-version re-import with changes gets its own tag" 1 "$(git tag --list 'upstream/9.9.11-1.2' | wc -l | tr -d ' ')"

# A clone has no local upstream branch, only origin/upstream.
git merge -q upstream -m m >/dev/null 2>&1
clone=$tmp/clone; git clone -q "$repo" "$clone" 2>/dev/null
cd "$clone" || exit 1
echo "// clone edit" >>"$fake/shell/plugins/notifications/Service.qml"
check "in a clone: exit 1" 1 "$(status_of tools/check-upstream)"
check "in a clone --diff finds origin/upstream" 1 "$(tools/check-upstream --diff 2>&1 | grep -c '^+// clone edit')"

echo
if (( fail == 0 )); then echo "ALL $pass CHECKS PASS"; else echo "$fail FAILED, $pass passed"; fi
exit $(( fail ? 1 : 0 ))
