#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_a_runtime_compiled_big_clause_costs_a_doubling_of_its_goals_about_twice_the_instructions.sh -- THE RUN-TIME PLANNER IS LINEAR IN A CLAUSE (hq_zetas, row
# prolog-swi-test-db-res-compiler-big-clause-hangs-in-both-modes-on-0150f42f3-after-the-gc-site-mask-cure). swi_tests db/test_db res_compiler:big_clause asserts and calls ONE clause of
# 60000 goals under library(plunit). The run-time planner (planner_stage_rt) ran its per-run passes over the whole graph once per RUN, and a plunit-loaded program ends a run at
# every goal (succ/2 retains there), so the planner spent about 304 x N^2 instructions (1.1e12 at N = 60000, 141 s in mode 3, 87 s then a stack overflow in mode 4); with the resets
# and the family scan indexed by run the cost is the clause's own, about 1.25e6 instructions a goal.
# THE GATE builds the res_compiler unit of the swi_tests db/test_db.pl at N = 1500, 3000 and 6000 goals (the same text, only the goal count replaced), runs each under
# library(plunit) as the suite runner does (scrip --run, the entry's declared heap and a 64 MB stack, the unit must print PASS res_compiler) and counts user instructions
# (perf stat -e instructions:u: a count, never a clock). Doubling the goals from 3000 to 6000 must cost at most 2.6 times what doubling 1500 to 3000 cost (linear reads 2.0-2.2; the
# quadratic planner read 3.07). --scrip PATH measures that binary instead of this tree's (the control arm: the parent's build reads RED).
# rc 0 held · rc 1 the cost grows faster than linearly (the numbers printed) or a run did not pass · rc 2 cannot measure (no scrip, no perf, a missing fixture)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"; SC="$ROOT/SCRIP/scrip"
NAME=test_gate_a_runtime_compiled_big_clause_costs_a_doubling_of_its_goals_about_twice_the_instructions
[ "${1:-}" != --scrip ] || { SC="${2:-}"; shift 2; }
[ -x "$SC" ] || { echo "REFUSE(2): $SC is not an executable scrip"; exit 2; }
SRC="$ROOT/corpus/packages/prolog/swi_tests/db/test_db.pl"; PLUNIT="$ROOT/corpus/packages/prolog/swi_tests/plunit.pl"
[ -f "$SRC" ] && [ -f "$PLUNIT" ] || { echo "REFUSE(2): no $SRC or $PLUNIT"; exit 2; }
PERF=""
for p in perf /usr/lib/linux-tools-*/perf; do command -v "$p" > /dev/null 2>&1 || [ -x "$p" ] || continue; "$p" stat -x, -e instructions:u -o /dev/null true > /dev/null 2>&1 && { PERF="$p"; break; }; done
[ -n "$PERF" ] || { echo "REFUSE(2): no perf that counts instructions:u on this kernel"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_bigclause.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
grep -q 'test_big_clause(60000)' "$SRC" || { echo "REFUSE(2): $SRC no longer calls test_big_clause(60000)"; exit 2; }
printf 'main :- run_tests.\n:- initialization(main).\n' > "$W/wrap.pl"
for n in 1500 3000 6000; do
    sed "s/test_big_clause(60000)/test_big_clause($n)/" "$SRC" | awk '/begin_tests\(res_compiler\)/{f=1} f{print} /end_tests\(res_compiler\)/{f=0}' | sed '1i :- use_module(library(plunit)).' > "$W/t$n.pl"
    [ -s "$W/t$n.pl" ] || { echo "REFUSE(2): no res_compiler unit in $SRC"; exit 2; }
done
count() {
    local n="$1" ins
    ( cd "$ROOT/SCRIP" && timeout -k 5 900 bash "$HERE/util_run_slot.sh" "$PERF" stat -x, -e instructions:u -o "$W/p$n.txt" -- "$SC" --run -d131072k -s65536k "$PLUNIT" "$W/t$n.pl" "$W/wrap.pl" < /dev/null > "$W/o$n.txt" 2> "$W/e$n.txt" )
    grep -q 'PASS res_compiler' "$W/o$n.txt" || { echo "RED: the res_compiler unit at $n goals did not print PASS res_compiler"; head -3 "$W/o$n.txt" "$W/e$n.txt" | cut -c1-160; exit 1; }
    ins="$(grep instructions "$W/p$n.txt" | cut -d, -f1)"
    case "$ins" in ''|*[!0-9]*) echo "REFUSE(2): no instruction count for $n goals"; exit 2 ;; esac
    echo "$ins"
}
i1="$(count 1500)" || exit $?; i2="$(count 3000)" || exit $?; i3="$(count 6000)" || exit $?
read -r ratio ok <<< "$(awk -v a="$i1" -v b="$i2" -v c="$i3" 'BEGIN { d1 = b - a; d2 = c - b; if (d1 <= 0) { print "0 refuse"; exit } r = d2 / d1; printf "%.2f %s\n", r, (r <= 2.6 ? "ok" : "red") }')"
echo "BIGCLAUSE_BOARD instructions: n=1500 $i1  n=3000 $i2  n=6000 $i3  doubling-ratio $ratio (limit 2.60)"
[ "$ok" != refuse ] || { echo "REFUSE(2): the cost did not rise with the goal count"; exit 2; }
[ "$ok" = ok ] && { echo "GATE OK [$NAME]: doubling the goals of a plunit-wrapped run-time clause costs $ratio times the previous doubling (linear is 2)"; exit 0; }
echo "GATE FAIL [$NAME]: doubling the goals costs $ratio times the previous doubling (limit 2.6): the run-time planner is superlinear in the clause"; exit 1
