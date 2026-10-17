#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⛔ NEW RED BISECTED TO THE SLOT-REUSE ROW'S RUNG 1 (hq_prolog, 2026-09-16, two fresh builds: e83244874 good,
# d21da7354 red): the SWI package board lost nine m3 cases in core/test_hash.pl -- the whole plunit unit yielded
# NO verdict under m3 while m4 answered.  MEASURED: m3 aborts inside the unit with FATAL drive_value_slot on an
# IR_VAR_FRAME of the run-time-defined predicate $mc:variant_sha1/2 (nodes=14) -- and the layout's record for
# that graph POINTER already existed from a DEAD graph (37 slots, 23 results, region 640, gdb-read), so
# zls_build() returned early ("already built") right after zls_forget_graph_nodes() had dropped the nodes'
# entries: no node had a grant.  The defect predates rung 1 (a graph record keyed by pointer survived the
# graph's death); rung 1's malloc/free of the reuse plan changed the allocation pattern that recycles the address.
# CURE: zls_forget_graph_nodes() retires the graph's record as well as its nodes (frame_layout.c), and the
# runtime-eval define path forgets before it drives, exactly as lower_prolog's does (runtime_eval.c).
# ⛔ THE WITNESS IS ONE CORPUS PROGRAM RUN AS A WITNESS, NOT A BOARD: the shape needs the file's exact
# allocation history (the variant_sha1 unit alone does not recycle the address), so this gate runs
# swi_tests/core/test_hash.pl under the SWI runner's exact m3 invocation and grades it with the runner's own
# matcher against the file's swipl ref; it writes no row.  PINS: (1) no FATAL on stderr; (2) the m3 verdict
# count equals the m4 verdict count on the same binary (20 and 20 today: 9 agree, 11 disagree, both modes);
# (3) under SCRIP_PL_RTASM=1 no run-time fragment reports max_granted_cell=-1 with nodes>0.
# RED-BEFORE (888f9a767): m3 rc=134, FATAL drive_value_slot op=133, m3 verdicts 0 of 20, RTASM
# "$mc:variant_sha1/2: nodes=14 ... max_granted_cell=-1".
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
CORPUS="${S4E_CORPUS:-$(cd "$ROOT/.." && pwd)/corpus}"
PLUNIT="$CORPUS/tests/prolog/plunit.pl"; F="$CORPUS/packages/prolog/swi_tests/core/test_hash.pl"; REF="${F%.pl}.ref"
for x in "$PLUNIT" "$F" "$REF" ../harness/scripts/util_swi_match.py; do [ -f "$x" ] || { echo "⛔ REFUSE(2): $x is absent -- nothing measured"; exit 2; }; done
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'main :- run_tests.\n:- initialization(main).\n' > "$T/wrap.pl"
bad=0
timeout -k 5 90 ./scrip --run "$PLUNIT" "$F" "$T/wrap.pl" < /dev/null > "$T/m3.out" 2> "$T/m3.err"; rc3=$?
grep -q 'FATAL' "$T/m3.err" && { echo "  ⛔ m3 aborted: $(grep -m1 FATAL "$T/m3.err" | cut -c1-120)"; bad=$((bad+1)); }
if timeout -k 5 90 ./scrip --compile "$PLUNIT" "$F" "$T/wrap.pl" > "$T/m4.s" 2>/dev/null && gcc -no-pie "$T/m4.s" -Lout -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/m4.bin" 2>/dev/null; then
    timeout -k 5 90 "$T/m4.bin" < /dev/null > "$T/m4.out" 2>/dev/null
else echo "⛔ REFUSE(2): mode 4 did not build the witness"; exit 2; fi
n3="$(python3 ../harness/scripts/util_swi_match.py "$F" "$REF" "$T/m3.out" | awk -F'\t' '$2=="PASS"||$2=="FAIL"' | wc -l)"
n4="$(python3 ../harness/scripts/util_swi_match.py "$F" "$REF" "$T/m4.out" | awk -F'\t' '$2=="PASS"||$2=="FAIL"' | wc -l)"
echo "test_hash.pl verdicts: m3=$n3 m4=$n4 (m3 rc=$rc3)"
[ "$n4" -gt 0 ] || { echo "⛔ REFUSE(2): mode 4 graded nothing -- the matcher cannot be trusted on this run"; exit 2; }
[ "$n3" = "$n4" ] || { echo "  ⛔ m3 graded $n3 case(s) where m4 graded $n4 -- the unit stopped yielding under m3"; bad=$((bad+1)); }
SCRIP_PL_RTASM=1 timeout -k 5 120 ./scrip --run "$PLUNIT" "$F" "$T/wrap.pl" < /dev/null > /dev/null 2> "$T/rt.err"
ng="$(grep -E '^\[RTASM\] .*: nodes=[1-9][0-9]* .*max_granted_cell=-1' "$T/rt.err" | wc -l)"
[ "$ng" = "0" ] || { echo "  ⛔ $ng run-time fragment(s) drove with no granted cell:"; grep -E '^\[RTASM\] .*max_granted_cell=-1' "$T/rt.err" | head -3 | cut -c1-140; bad=$((bad+1)); }
if [ "$bad" -gt 0 ]; then echo "⛔ GATE FAIL: $bad finding(s) -- a dead graph's layout record is still answering for a live graph"; exit 1; fi
echo "GATE OK: test_hash.pl yields $n3 verdicts in both modes with no abort, and every run-time fragment is granted"
