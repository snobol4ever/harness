#!/bin/bash
# test_prolog_bb_honest.sh — run Prolog corpus under SCRIP_NO_AST_WALK=1 --run.
# Reports PASS=N where N grows as GOAL-PROLOG-BB-COMPLETE Phase A rungs land.
# A PASS here means "honest mode 3": SM dispatch did not fall back to the AST walker.
# A FAIL/ABORT here means the program still cheats (coro_eval reached from SM dispatch).
#
# PB-0 (GOAL-PROLOG-BB-COMPLETE): initial script; baseline N=17 (--run oracle, 2026-05-12).
# Note: PLAN.md carve estimate of 31 was measured against .expected files (includes programs
# that --run itself cannot run). This script uses --run as oracle (stricter, correct).
# Usage: bash ../harness/scripts/test_prolog_bb_honest.sh [--corpus PATH] [--scrip PATH]
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus/tests/prolog}"

if [ ! -x "$SCRIP" ]; then echo "SKIP scrip not found at $SCRIP"; exit 0; fi
if [ ! -d "$CORPUS" ]; then echo "SKIP corpus not found at $CORPUS"; exit 0; fi

pass=0; fail=0; abort=0; ocrash=0

for f in "$CORPUS"/rung*.pl; do
    name=$(basename "$f" .pl)
    base="${f%.pl}"

    # Use --run as the oracle for expected output
    ir_out=$(timeout -k 5 8 "$SCRIP" --run "$f" < /dev/null 2>&1)
    ir_rc=$?

    # Only test programs that pass --run.  PL-Z-1a INSTRUMENT NOTE: programs whose ORACLE run
    # itself crashes/hangs were silently dropped from the denominator, so a broken class
    # (e.g. multi-clause predicate SEGV, measured 2026-08-16) hid behind PASS=N FAIL=0.
    # ORACLE_CRASH counts them visibly; PASS/FAIL/ABORT semantics and the exit code are UNCHANGED.
    if [ $ir_rc -ne 0 ]; then ocrash=$((ocrash + 1)); continue; fi

    sm_out=$(timeout -k 5 8 bash -c "SCRIP_NO_AST_WALK=1 '$SCRIP' --run '$f' < /dev/null 2>&1")
    sm_rc=$?

    if [ $sm_rc -eq 134 ] || echo "$sm_out" | grep -q "FATAL: .*reached from SM dispatch"; then
        abort=$((abort + 1))
    elif [ "$sm_out" = "$ir_out" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
    fi
done

echo "=== honest mode-3 (SCRIP_NO_AST_WALK=1 --run) ==="
echo "PASS=$pass FAIL=$fail ABORT=$abort ORACLE_CRASH=$ocrash"
echo "(PASS = honest; ABORT = cheating via AST walker; FAIL = wrong output; ORACLE_CRASH = --run oracle itself rc!=0, excluded from denominator)"
# R-0h (GOAL-PROLOG-100): ORACLE_CRASH gates the exit — a crashing engine can never report green.
[ $fail -eq 0 ] && [ $abort -eq 0 ] && [ $ocrash -eq 0 ] && exit 0 || exit 1
