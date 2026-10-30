#!/bin/bash
# Tests components/SlotMotion.qml offscreen with the real Qt Quick runtime (no GPU needed): its timing,
# monotonic curves, callbacks, and that the stock (non-themed) path does nothing.
#
#   bash test/motion-test.sh
#
# Each check was confirmed to fail when the component was broken on purpose.
set -u
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
QML=${QML:-/usr/lib/qt6/bin/qml}
pass=0 fail=0
check() { if [[ $2 == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: want [$2] got [$3]"; fi; }
near() { # name value low high
  if awk -v v="$2" -v lo="$3" -v hi="$4" 'BEGIN{exit !(v>=lo && v<=hi)}'; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: $2 not in [$3, $4]"; fi
}

out=$(env -u DISPLAY -u WAYLAND_DISPLAY QT_QPA_PLATFORMTHEME= QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  QT_LOGGING_TO_CONSOLE=1 QT_FORCE_STDERR_LOGGING=1 timeout 30 "$QML" "$HERE/motion-logic.qml" 2>&1)
rc=$?
check "the test scene ran to the end" 0 "$rc"
get() { sed -n "s/^.*T $1 //p" <<<"$out" | head -n1; }

check "stock: enter changes nothing" 1 "$(get 'stock presence after enter')"
check "stock: leave calls back at once" 1 "$(get 'stock leave called back at once')"
check "stock: it never enters the leaving state" false "$(get 'stock leaving')"
check "stock: values are the settled ones" "1 1 1 0 false" "$(get 'stock values')"

check "themed: presence is 0 right after enter" 0 "$(get 'themed presence right after enter')"
check "themed: at 0 the card is invisible, small, and the slot trims its gap" "0 0 0.94 -8 true" "$(get 'themed values at 0')"
check "themed: the designed durations (ms)" "480 300" "$(get 'themed durations')"
check "slowdown multiplies them" "1920 1200" "$(get 'slow durations')"
near "themed: not front-loaded: at ~80 ms the entry is well short of done" "$(get 'themed presence at ~80ms')" 0.15 0.65
near "themed: partway through the entry" "$(get 'themed presence at ~160ms')" 0.4 0.95
near "slowed 4x: at 480 ms (a quarter of its 1920 ms) the entry is still far from done" "$(get 'slow presence at ~480ms')" 0.3 0.85
check "themed: the entry only ever rises" true "$(get 'themed enter monotonic')"
check "themed: it ends at 1" 1 "$(get 'themed presence after entry')"
check "themed: settled values" "1 1 1 0 false" "$(get 'themed values settled')"
check "themed: leaving is flagged" true "$(get 'themed leaving')"
near "themed: partway through the exit" "$(get 'themed presence at ~120ms of exit')" 0 0.9
check "themed: the exit only ever falls" true "$(get 'themed exit monotonic')"
check "themed: it ends at 0" 0 "$(get 'themed presence after exit')"
check "themed: done is called exactly once, and a second leave is ignored" 1 "$(get 'done calls')"
check "themed: done saw it finished" 0 "$(get 'themed done called, presence')"
check "themed: folded slots clip" true "$(get 'clipping when folded')"

echo
if (( fail == 0 )); then echo "ALL $pass CHECKS PASS"; else echo "$fail FAILED, $pass passed"; fi
exit $(( fail ? 1 : 0 ))
