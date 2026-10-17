#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_zcells_gva.sh — ZK-5 GATE: globals stay OFF the cells-arm ZD spine (GVA/NV path, not ζ cells)
#
# THREE CHECKS:
#   1. CORRECTNESS: CELLS=1 global witness produces same output as baseline.
#   2. ASSERTION: SCRIP_ZD_CENSUS=1 run does NOT abort (ZK-5 global-cells=0 invariant held).
#   3. CENSUS: census shows 0 armed nodes for the global-only witness program (globals all refused).
#
# Completion criterion (ZK-5): these three checks green on the global witness.
#
# ⛔ CHECK 1 WAS A TAUTOLOGY; DRIVER VARIABLE REPAIRED (s247, seat1, rung N-0).  The gate compared a baseline
# run against a "SCRIP_ICN_CELLS=1" run and called the equality a correctness result.  Z-1 (s230, db728001)
# made SCRIP_ICN_CELLS A NO-OP unless SCRIP_ICN_LEGACY=1 is set too, so BOTH SIDES WERE THE SAME
# CONFIGURATION and the comparison could not fail for any reason in this gate's subject.  CHECK 1 is now the
# real anchor: the default arm (which IS the cells arm) against the pinned .expected, and a missing .expected
# is a hard failure rather than a silent pass through the else-branch.  ⛔ The pre-Z-1 A/B cannot be restored:
# SCRIP_ICN_LEGACY=1 CORE-DUMPS on this witness (measured s247), so the transition killswitch no longer
# reproduces a working configuration — recorded in GOAL-ICON-100 as evidence for the N-5 fold.
# Authors: LCherryholmes · Claude Sonnet 4.6

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
# ⭐ seat03 2026-08-30: re-pointed off the loose tests/scrip_test/icon/... original (absorbed into
# the icon rungs, icon-scrip-test-icn-absorption) -- materialize it fresh via lib_rungs_extract.sh
# rather than reading a file that may no longer be on disk. The rungs' oracle-verified .ref IS
# this witness's .expected (same semantic role: the pinned correct output).
RUNGS_DIR="$HERE/../../corpus/tests/icon" RUNGS_EXT=.icn source "$HERE/lib_rungs_extract.sh"
EXTRACT_DIR="$(mktemp -d)"
trap 'rm -rf "$EXTRACT_DIR"' EXIT
WITNESS="$EXTRACT_DIR/zk5_global_cells_zero.icn"
EXPECTED="$EXTRACT_DIR/zk5_global_cells_zero.expected"
rungs_extract_origin "scrip_test_icon_zk5_global_cells_zero__zk5_global_cells_zero" "$WITNESS" "$EXPECTED" \
    || { echo "GATE FAIL: could not extract zk5_global_cells_zero witness from the icon rungs"; exit 1; }
FAIL=0

[ -x "$SCRIP" ] || { echo "GATE SKIP: scrip not built at $SCRIP"; exit 0; }
[ -f "$WITNESS" ] || { echo "GATE FAIL: witness not found at $WITNESS"; exit 1; }

# CHECK 1 — correctness: the DEFAULT arm (= the cells arm since Z-1) against the pinned oracle
[ -f "$EXPECTED" ] || { echo "GATE FAIL: .expected not found at $EXPECTED — the gate has no oracle to check against"; FAIL=1; }
base_out=$(timeout -k 5 8s "$SCRIP" --run "$WITNESS" 2>/dev/null) || { echo "GATE FAIL: default-arm run failed"; FAIL=1; }
if [ -f "$EXPECTED" ] && [ "$base_out" != "$(cat "$EXPECTED")" ]; then
    echo "GATE FAIL: default-arm output does not match .expected"
    echo "  got:      $base_out"
    echo "  expected: $(cat "$EXPECTED")"
    FAIL=1
elif [ -f "$EXPECTED" ]; then
    echo "CHECK 1 PASS: default-arm output matches .expected"
fi

# CHECK 2 — ZK-5 assertion: census run must not abort (global-cells=0 invariant)
census_stderr=$(SCRIP_ZD_CENSUS=1 timeout -k 5 8s "$SCRIP" --run "$WITNESS" 2>&1 >/dev/null) || { echo "GATE FAIL: CENSUS=1 run crashed/aborted"; FAIL=1; }
if grep -q "ZK-5-FAIL" <<< "$census_stderr"; then
    echo "GATE FAIL: ZK-5 global-cells=0 assertion FIRED -- a global was armed on the cells spine"
    echo "$census_stderr" | grep "ZK-5-FAIL"
    FAIL=1
else
    echo "CHECK 2 PASS: ZK-5 assertion did not fire (no global armed on cells arm)"
fi

# CHECK 3 — census: armed=0 for the global-only witness
armed=$(echo "$census_stderr" | grep "^\[ZK-CENSUS\]" | grep -oP "armed=\K[0-9]+" | head -1)
if [ "${armed:-x}" != "0" ]; then
    echo "GATE FAIL: expected armed=0 for global-only witness, got armed=${armed:-<not found>}"
    FAIL=1
else
    echo "CHECK 3 PASS: census armed=0 (globals correctly excluded from cells spine)"
fi

if [ "$FAIL" -eq 0 ]; then
    echo "ZK-5 GATE: PASS"
    exit 0
else
    echo "ZK-5 GATE: FAIL"
    exit 1
fi
