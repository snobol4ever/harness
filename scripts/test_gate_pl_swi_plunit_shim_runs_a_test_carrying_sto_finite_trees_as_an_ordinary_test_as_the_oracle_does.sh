#!/bin/bash
# test_gate_pl_swi_plunit_shim_runs_a_test_carrying_sto_finite_trees_as_an_ordinary_test_as_the_oracle_does.sh -- THE SHIM RUNS WHAT THE ORACLE RUNS (ceo CEO-1959, hq_packages; SWI core/test_occurs_check.pl and test_dcg uwn4).
# swipl 9.0.4's plunit runs a test whose own options carry sto(Type) as an ORDINARY test unless the global option sto(true) is given (run_test_once/5: option(sto(false), GlobalOptions, false) selects
# run_test_6 with no unification mode), so [sto(finite_trees),fail] with a goal that succeeds reads "must fail but succeeded" in the oracle's ref. The corpus's plunit shim SKIPPED every sto(Type) but
# rational_trees ("skip [sto]"), so three cases of core/test_occurs_check.pl (unify#1, unify#2, unifiable#1) and test_dcg uwn4 read oracle FAIL / scrip skip. It now strips sto(_) and runs the test as the oracle does:
# the board reads every graded case of the file a pass in BOTH modes, three of them as agreement controls (both engines fail them identically). The witness is the vendored file graded against its oracle-cut refs.
# rc 0 graded=9 and m3_pass=m4_pass=9 with agree_fail=3; rc 1 a case differs; rc 2 cannot measure (no ./scrip, no suite runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
[ -x ./scrip ] && [ -f "$HERE/test_prolog_swi_suite.sh" ] || { echo "REFUSE(2): no ./scrip or no suite runner"; exit 2; }
T="$HERE/../../.scratch/stoo-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
S4E_PROGRESS_OFF=1 timeout -k 5 600 bash "$HERE/test_prolog_swi_suite.sh" --file core/test_occurs_check.pl --modes m3,m4 --name-reds > "$T/o.txt" 2>&1; rc=$?
line="$(grep -m1 '^SWI_BOARD' "$T/o.txt")"
[ -n "$line" ] || { echo "REFUSE(2): the suite runner printed no SWI_BOARD line (rc=$rc)"; head -3 "$T/o.txt" | cut -c1-200; exit 2; }
echo "$line" | cut -c1-200
g="$(echo "$line" | sed -n 's/.* graded=\([0-9]*\) .*/\1/p')"; p3="$(echo "$line" | sed -n 's/.* m3_pass=\([0-9]*\) .*/\1/p')"; p4="$(echo "$line" | sed -n 's/.* m4_pass=\([0-9]*\) .*/\1/p')"; a3="$(echo "$line" | sed -n 's/.* m3_agree_fail=\([0-9]*\) .*/\1/p')"
if [ "$g" = 9 ] && [ "$p3" = 9 ] && [ "$p4" = 9 ] && [ "$a3" = 3 ]; then echo "GATE OK -- core/test_occurs_check.pl: all 9 graded cases pass in both modes, 3 of them as agreement controls (the sto(finite_trees) cases run as ordinary tests, as the oracle runs them)"; exit 0; fi
echo "GATE FAIL -- graded=$g m3_pass=$p3 m4_pass=$p4 m3_agree_fail=$a3 (want 9 9 9 3); the reds:"
grep '  RED ' "$T/o.txt" | cut -c1-180 | head -6
exit 1
