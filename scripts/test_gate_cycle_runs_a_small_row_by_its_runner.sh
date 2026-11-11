#!/usr/bin/env bash
# test_gate_cycle_runs_a_small_row_by_its_runner.sh -- the test cycle runs a row of kind small (a demos row, a bench-ref row, GNU source) as ONE
# cell, by the runner the row names, so no suite of the banner stands outside the cycle (the coo 2026-11-11, on Lon's word in the coo's window,
# verbatim: "get all test suites graded and plugged into new cycle runner."; MEASURED before the cure by util_cycle_inventory.py: 15 rows of kind
# small, no cell in any lap). cells, small_budget and run_cell are taken from s4e_cycle.sh and asked over a planted runner table and a planted
# runner in a scratch root; no cycle is run, no slot of the box is taken (the scratch root's util_run_slot.sh only runs its words) and no live
# file is read or written.
#
# THE ARMS:
#   1  a small row is one cell named all, carrying the runner's own words, in the table's order among the master and pkg rows; a small row with
#      no runner (-), a row of kind none and a port row give no cell
#   2  the cell runs the row's runner with the row's words and returns the runner's own exit status (1 here: a red is a red)
#   3  a runner that takes --no-write is asked not to write the suite row (the cycle records it from the progress rows); one that does not is run bare
#   4  the cap is five times the cell's last graded seconds, at least 300, at most 3600, and 1800 for a cell never graded
# EXIT: 0 all arms pass, 1 an arm failed (or the script lists no small cell), 2 REFUSED (no script, no scratch directory).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=cycle_runs_a_small_row_by_its_runner
CYC="$HERE/s4e_cycle.sh"
[ -f "$CYC" ] || { echo "REFUSE(2) [$NAME]: no $CYC"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_cycle_small.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
F="$(sed -n '/^cells() {/,/^}/p; /^small_budget() {/,/^}/p; /^budget() {/p; /^ext_of() {/p; /^suite_on_disk() {/,/^}/p; /^road_flag() {/,/^}/p; /^run_cell() {/,/^}/p' "$CYC")"
pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }
R="$T/root"; mkdir -p "$R/harness/scripts" "$R/corpus/tests/lang" "$T/tmp/cycle" || { echo "REFUSE(2) [$NAME]: no scratch root"; exit 2; }
printf 'entry\tpart\na\tcore\nb\tchunk:01\n' > "$R/corpus/tests/lang/PARTITION.tsv"
printf '# planted\nm1\tmaster\tlang\tcorpus_suite_harness.py\tcorpus/tests/lang\ns1\tsmall\tlang\trunner_w.sh one two\t-\ns2\tsmall\tlang\t-\t-\nn1\tnone\tlang\t-\t-\np1\tport\tlang\trunner_w.sh\t-\ns3\tsmall\tlang\trunner_b.sh\t-\n' > "$R/harness/scripts/SUITE_RUNNERS.tsv"
printf '#!/usr/bin/env bash\n"$@"\n' > "$R/harness/scripts/util_run_slot.sh"
printf '#!/usr/bin/env bash\n# takes --no-write\nprintf "%%s\\n" "$*" > "%s/w.args"\nexit 1\n' "$T" > "$R/harness/scripts/runner_w.sh"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" > "%s/b.args"\nexit 0\n' "$T" > "$R/harness/scripts/runner_b.sh"
printf 's1\tall\t100\ns3\tall\t7\nbig\tall\t9000\n' > "$T/CYCLE.order"
ask() { S4E="$R" RUNNERS="$R/harness/scripts/SUITE_RUNNERS.tsv" TMPDIR="$T/tmp" ORDERF="$T/CYCLE.order" S4E_MODES=m3 bash -c "$F"'; '"$1" 2> /dev/null; }
g1="$(ask cells | cut -f1,2,4,5 | tr '\t\n' ' ;')"
if ! printf '%s' "$g1" | grep -q ' small '; then
    ck no "(1) s4e_cycle.sh lists no cell for a small row: read [$g1]"; ck no "(2) no small cell to run"; ck no "(3) no small cell to run"; ck no "(4) no small cell to cap"
else
    [ "$g1" = "m1 master $R/corpus/tests/lang core;m1 master $R/corpus/tests/lang chunk:01;s1 small runner_w.sh one two all;s3 small runner_b.sh all;" ] && ck ok "(1) a small row is one cell named all with its runner's words, in the table's order; no runner, none and port give none" || ck no "(1) read [$g1]"
    g2="$(ask 'run_cell s1 small lang "runner_w.sh one two" all')"; a2="$(cat "$T/w.args" 2> /dev/null)"
    case "$g2" in "1 "*) case "$a2" in "one two"*) ck ok "(2) the cell ran the row's runner with the row's words and returned its exit status 1";; *) ck no "(2) the runner saw [$a2]";; esac;; *) ck no "(2) run_cell answered [$g2], the runner saw [$a2]";; esac
    g3="$(ask 'run_cell s3 small lang "runner_b.sh" all')"; a3="$(cat "$T/b.args" 2> /dev/null; echo .)"
    [ "$a2" = "one two --no-write" ] && [ "$a3" = "
." ] && [ "${g3%% *}" = 0 ] && ck ok "(3) a runner that takes --no-write is asked not to write the row; one that does not is run bare" || ck no "(3) the first saw [$a2], the second saw [$a3] and answered [$g3]"
    g4="$(ask 'small_budget s1; small_budget s3; small_budget big; small_budget never' | tr '\n' ' ')"
    [ "$g4" = "500 300 3600 1800 " ] && ck ok "(4) the cap is five times the last graded seconds, at least 300, at most 3600, 1800 with no reading" || ck no "(4) read [$g4]"
fi
echo "CYCLE_SMALL_BOARD arms=4 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 4 ] && { echo "GATE OK [$NAME]: a small row is one cell of the lap, run by its runner"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
