#!/usr/bin/env bash
# GATE-RK3 — Raku mode-3 honest native (SCRIP_M3_NATIVE=1 ./scrip --run).
# Mirrors test_raku_mode4_rung.sh's corpus loop; compares native stdout vs .expected.
SCRIP="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
[ -d "$SCRIP/test/raku" ] || SCRIP="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$SCRIP/scrip}"
TESTDIR="$SCRIP/test/raku"
[ -x "$SCRIP" ] || { echo "FAIL scrip not built"; exit 1; }
if [ ! -d "$TESTDIR" ]; then
    echo "⛔ REFUSING (rc=2): $TESTDIR not found -- test/raku is retired, this script cannot measure" >&2
    exit 2
fi
PASS=0; FAIL=0; SKIP=0; CRASH=0
for rk in "$TESTDIR"/*.raku; do
    [ -f "$rk" ] || continue
    exp="${rk%.raku}.expected"; name="$(basename "$rk" .raku)"
    [ -f "$exp" ] || { SKIP=$((SKIP+1)); continue; }
    WANT="$(cat "$exp")"
    GOT="$(SCRIP_M3_NATIVE=1 timeout -k 5 12 "$SCRIP" --run "$rk" </dev/null 2>/dev/null)"; rc=$?
    if [ $rc -ge 128 ]; then echo "  CRASH $name (rc=$rc)"; CRASH=$((CRASH+1)); FAIL=$((FAIL+1)); continue; fi
    if [ "$WANT" = "$GOT" ] && [ -n "$WANT" ]; then echo "  PASS $name"; PASS=$((PASS+1));
    else echo "  FAIL $name"; FAIL=$((FAIL+1)); fi
done
echo "--- Raku (mode-3 native): PASS=$PASS FAIL=$FAIL CRASH=$CRASH TOTAL=$((PASS+FAIL)) ---"
