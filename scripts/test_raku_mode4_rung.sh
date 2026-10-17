#!/usr/bin/env bash
# test_raku_mode4_rung.sh — RAKU-BB RK-BB-1 (GOAL-RAKU-100.md)
# Mode-4 Raku correctness gate. For each test/raku/*.raku that has a .expected,
# compile via `scrip --compile --target=x86`, assemble, link, run, and diff
# stdout against the .expected golden. Reports PASS=N FAIL=M SKIP=K.
#
# Gate threshold (RK-BB-1): mode-4 PASS >= 1 (the lazy-range generative case
# rk_range_for) before RK-BB-1 is marked complete. Many eager .raku cases will
# FAIL or be SKIPPED while the rest of the mode-4 Raku surface lands — the gate
# measures the generative-path gap, mirroring Prolog GATE-4.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$SCRIP/scrip}"
LIBRT="${LIBRT:-$SCRIP/out/libscrip_rt.so}"
RUNNER="$HERE/run_raku_via_x86_backend.sh"
TESTDIR="$SCRIP/test/raku"
[ -x "$SCRIP" ] || { echo "FAIL scrip not built: $SCRIP"; exit 1; }
[ -f "$LIBRT" ] || { echo "FAIL libscrip_rt.so not built: $LIBRT (run 'make libscrip_rt')"; exit 1; }
[ -d "$TESTDIR" ] || { echo "⛔ REFUSED-TO-GRADE no test/raku dir"; exit 2; }

PASS=0; FAIL=0; SKIP=0
for rk in "$TESTDIR"/*.raku; do
    [ -f "$rk" ] || continue
    exp="${rk%.raku}.expected"
    name="$(basename "$rk" .raku)"
    [ -f "$exp" ] || { echo "  SKIP $name (no .expected)"; SKIP=$((SKIP+1)); continue; }
    WANT="$(cat "$exp")"
    GOT="$(timeout -k 5 12 bash "$RUNNER" "$rk" 2>/dev/null)" || true
    if [ "$WANT" = "$GOT" ] && [ -n "$WANT" ]; then
        echo "  PASS $name"; PASS=$((PASS+1))
    else
        echo "  FAIL $name"; FAIL=$((FAIL+1))
    fi
done
echo "--- Raku (mode-4 x86): PASS=$PASS FAIL=$FAIL SKIP=$SKIP TOTAL=$((PASS+FAIL)) ---"
[ "$PASS" -ge 1 ] && exit 0 || exit 1
