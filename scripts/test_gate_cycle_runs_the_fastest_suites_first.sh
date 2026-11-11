#!/usr/bin/env bash
# test_gate_cycle_runs_the_fastest_suites_first.sh -- the test cycle orders a lap's cells by their SUITE's time (the sum of the seconds its cells
# took the last time each graded), the fastest suite first, a suite with no reading before every known one, a suite's cells together, and the
# order is frozen for the lap (the coo 2026-11-11, COO-515, on Lon's word: "So regarding the order in which the test suites should be run, from
# fastest to slowest."; it replaces test_gate_cycle_runs_the_longest_cells_first.sh, COO-510, whose order Lon reversed the same morning).
# order_write and order_cells are taken from s4e_cycle.sh and asked over a planted log; no cycle is run and no live file is read or written.
#
# THE ARMS:
#   1  fastest suite first: the suite with no reading leads, then the suites by their summed seconds, each suite's cells together in the table's order
#   2  a refused cell (rc=2 secs=0) does not erase the seconds of its last graded run; a later graded run replaces an earlier one
#   3  frozen for the lap: a CELL line added to the log after order_write changes nothing until order_write runs again
#   4  with no CYCLE.order the cells keep the table's order (a restart under a script that has just taken over reads the old list)
# EXIT: 0 all arms pass, 1 an arm failed (or the script has no order_write and order_cells), 2 REFUSED (no script, no scratch directory).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=cycle_runs_the_fastest_suites_first
CYC="$HERE/s4e_cycle.sh"
[ -f "$CYC" ] || { echo "REFUSE(2) [$NAME]: no $CYC"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_cycle_order.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
F="$(sed -n '/^order_write() {/p; /^order_cells() {/,/^}/p' "$CYC")"
pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }
cellrow() { printf '%s\tpkg\tlang\t/dir\t%s\n' "$1" "$2"; }
table() { cellrow a core; cellrow b chunk:01; cellrow b chunk:02; cellrow c core; cellrow d core; }
ask() { LOG="$T/CYCLE.log" ORDERF="$T/CYCLE.order" bash -c "$F"'; '"$1" 2> /dev/null | cut -f1,5 | tr '\t\n' ' ;'; }
cat > "$T/CYCLE.log" <<'LOGEOF'
2026-11-11T00:00:01Z LAP 1 start sync_rc=0 make_rc=0
2026-11-11T00:00:02Z CELL lap=1 1/5 a core rc=0 secs=10
2026-11-11T00:00:03Z CELL lap=1 2/5 b chunk:01 rc=1 secs=500
2026-11-11T00:00:04Z CELL lap=1 3/5 b chunk:02 rc=1 secs=300
2026-11-11T00:00:05Z CELL lap=1 4/5 c core rc=0 secs=50
2026-11-11T00:00:06Z CELL lap=2 3/5 b chunk:02 rc=2 secs=0
2026-11-11T00:00:07Z CELL lap=2 4/5 c core rc=1 secs=70
LOGEOF
if [ -z "$F" ]; then
    ck no "(1) s4e_cycle.sh has no order_write and order_cells: a lap runs in the table's order"; ck no "(2) no order to ask"; ck no "(3) no order to ask"; ck no "(4) no order to ask"
else
    g1="$(table | ask 'order_write; order_cells')"
    [ "$g1" = "d core;a core;c core;b chunk:01;b chunk:02;" ] && ck ok "(1) the unknown suite leads, then the suites fastest first, a suite's cells together" || ck no "(1) read [$g1]"
    grep -q -P '^b\tchunk:02\t300$' "$T/CYCLE.order" && grep -q -P '^c\tcore\t70$' "$T/CYCLE.order" && ck ok "(2) a refusal keeps the last graded seconds and a later graded run replaces an earlier one" || ck no "(2) CYCLE.order: $(tr '\t\n' ' ;' < "$T/CYCLE.order")"
    echo '2026-11-11T00:00:08Z CELL lap=2 1/5 a core rc=0 secs=9000' >> "$T/CYCLE.log"
    g3="$(table | ask 'order_cells')"; g3b="$(table | ask 'order_write; order_cells')"
    [ "$g3" = "$g1" ] && [ "$g3b" = "d core;c core;b chunk:01;b chunk:02;a core;" ] && ck ok "(3) the order is frozen until the next lap writes it" || ck no "(3) before [$g3] after [$g3b]"
    rm -f "$T/CYCLE.order"; g4="$(table | ask 'order_cells')"
    [ "$g4" = "a core;b chunk:01;b chunk:02;c core;d core;" ] && ck ok "(4) with no CYCLE.order the table's order stands" || ck no "(4) read [$g4]"
fi
echo "CYCLE_ORDER_BOARD arms=4 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 4 ] && { echo "GATE OK [$NAME]: a lap runs its fastest suites first, in an order frozen for the lap"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
