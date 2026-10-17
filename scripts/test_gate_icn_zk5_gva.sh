#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_zk5_gva.sh — ZK-5 GATE: globals_on_stack=0 on the cells arm
# CHARTER: IR_VAR/IR_ASSIGN nodes with a global name must NEVER appear armed (zd_on=1)
# on the FORTH-spine ZD regime.  Globals are process-lifetime storage (GVA/NV), not
# control-flow-lifetime ζ; their stack-cell count must be 0 by construction.
# ONE AUTHORITY: the !_icn_cells conjunct in zd_wl_kind (emit.cpp) is the sole guard;
# this script is its falsification criterion per the ZK-0 FALSIFIABILITY rule.
# WITNESS: global_heavy.icn (three globals, one local binop) -- if any global leaks
# onto the spine the counter > 0 and grep finds it.
# COMPLETION: exit 0 = ZK-5 GVA assertion green.
#
# ⛔ DRIVER VARIABLE REPAIRED (s247, seat1, rung N-0).  Every check drove the witness with
# SCRIP_ICN_CELLS=1.  Z-1 (s230, db728001) made that variable A NO-OP: lower_icon.c reads SCRIP_ICN_CELLS
# ONLY when SCRIP_ICN_LEGACY=1 is also set, and otherwise stamps icn_cells_graph=1 unconditionally.  The
# gate was therefore driving the DEFAULT arm while believing it had selected the cells arm — true, but by
# accident, and it would have gone on printing PASS if the cells arm had been switched off entirely.  The
# checks now name the default arm, which IS the cells arm.  ⛔ Do not "restore" the variable: the arm it
# selected no longer exists as a separate configuration, and SCRIP_ICN_LEGACY=1 core-dumps on this very
# witness (measured s247) — the Z-1 killswitch does not restore a working configuration any more, which is
# recorded in GOAL-ICON-100 as evidence for the N-5 fold.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -e
SCRIP=${SCRIP:-./scrip}
CORPUS=${CORPUS:-$S4E/corpus}
PASS=0; FAIL=0
check() {
    local label="$1" prog="$2"
    local out rc
    out=$(SCRIP_ZD_CENSUS=1 timeout -k 5 8s "$SCRIP" --run "$prog" </dev/null 2>&1); rc=$?; true
    # must produce correct output (rc=0) and no globals_on_stack > 0
    local bad
    bad=$(printf '%s\n' "$out" | grep 'globals_on_stack=' | grep -v 'globals_on_stack=0' || true)
    if [ $rc -ne 0 ]; then
        echo "FAIL [$label] scrip rc=$rc"
        FAIL=$((FAIL+1))
    elif [ -n "$bad" ]; then
        echo "FAIL [$label] globals_on_stack>0:"
        printf '%s\n' "$bad"
        FAIL=$((FAIL+1))
    else
        echo "PASS [$label] globals_on_stack=0 on all graphs"
        PASS=$((PASS+1))
    fi
}
# lock 1: inline witness (three globals, write-heavy)
cat > /tmp/zk5_global_witness.icn << 'EOF'
global x, y, z;
procedure main();
  x := 1;
  y := 2;
  z := x + y;
  write(z);
end
EOF
check "global_write_heavy" /tmp/zk5_global_witness.icn
# lock 2: palindrome.icn from corpus (global-heavy ZK-0 table entry)
if [ -f "$CORPUS/tests/icon/palindrome.icn" ]; then
    check "palindrome" "$CORPUS/tests/icon/palindrome.icn"
else
    echo "SKIP palindrome.icn (corpus not found)"
fi
# lock 3: local-only program must still show globals_on_stack=0 (trivially -- no globals)
cat > /tmp/zk5_local_only.icn << 'EOF'
procedure main();
  local x;
  x := 42;
  write(x);
end
EOF
check "local_only" /tmp/zk5_local_only.icn
echo "ZK-5 GVA GATE: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ]
