#!/usr/bin/env bash
# test_gate_done_runs_no_board_for_any_seat.sh -- DONE RUNS NO BOARD FOR ANY SEAT (ceo CEO-1342 clause 5; the coo's row
# bus-done-runs-no-board-for-any-seat-a-done-when-that-needs-a-suite-verdict-reads-the-coos-suite-table-row-at-a-tree-at-or-after-the-landing).
# THE DEFECT: MODE's LANES line names the coo for every language, so every other seat's board run refuses rc=2 -- except through
# `s4e_msg.sh done`, which exported S4E_DONE_WHEN_RUN=1 around a computed DONE-WHEN and both one-runner guards ADMITTED that run
# ("exempt, one run per closure"): the one road by which a non-tester seat still ran a suite.
# THE CURE, PROVEN HERE:
#   1  lib_one_runner.sh REFUSES rc=2 under S4E_DONE_WHEN_RUN=1 for an officer seat on a board, naming the rule and the row to read;
#   2  corpus_suite_harness.py's guard refuses the same way (both copies, one sentence);
#   3  util_suite_row_at_or_after.sh answers what a DONE-WHEN reads instead: rc 0 when the coo's row was measured at or after the
#      landing (the row printed), rc 1 when before (wait for the loop), rc 2 for an unknown key or tree;
#   4  util_donewhen_exemption_census.py NAMES a live baton whose DONE-WHEN runs a board (class BOARD) so its lane rewrites it;
#   5  FAIL-ONCE: a copy of lib_one_runner.sh with the old exemption planted back admits the run -- this gate reads that as the defect.
# EXIT: 0 every arm holds; 1 an arm failed; 2 could not measure. Population printed. Hermetic: a scratch S4E_HOME, no board runs.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=done_runs_no_board_for_any_seat
gate_parse_args "$@"
L="$HERE/lib_one_runner.sh"; H="$HERE/corpus_suite_harness.py"; RA="$HERE/util_suite_row_at_or_after.sh"; XC="$HERE/util_donewhen_exemption_census.py"
for f in "$L" "$H" "$RA" "$XC"; do gate_require "$f" "$(basename "$f")" || exit 2; done
CORPUS="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}/corpus"
gate_require "$CORPUS/tests/rebus/ALL.reb" "the rebus rungs (a real board path for the guard to judge)" || exit 2
W=$(mktemp -d) || exit 2; trap 'git -C "$ROOT" worktree remove --force "$W/home/SCRIP" >/dev/null 2>&1; rm -rf "$W"' EXIT INT TERM
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }

echo "--- ARM 1: the bash guard refuses the bus computed done on a board, for an officer seat, naming the rule ---"
o1=$(S4E_SEAT=cto S4E_DONE_WHEN_RUN=1 bash -c "source \"$L\"; one_runner_guard test_x_suite.sh \"$CORPUS/tests/rebus/ALL.reb\"" 2>&1); r1=$?
ck "1a rc 2, DONE RUNS NO BOARD FOR ANY SEAT named, util_suite_row_at_or_after.sh named" '[ "$r1" = 2 ] && grep -q "DONE RUNS NO BOARD FOR ANY SEAT" <<<"$o1" && grep -q "util_suite_row_at_or_after.sh" <<<"$o1"'
o1b=$(S4E_SEAT=hq_icon S4E_DONE_WHEN_RUN=1 bash -c "source \"$L\"; one_runner_guard test_x_suite.sh \"$CORPUS/tests/rebus/ALL.reb\"" 2>&1); r1b=$?
ck "1b and a language HQ under the same variable is refused as before (ONE SEAT, ONE LANGUAGE)" '[ "$r1b" = 2 ]'
o1c=$(S4E_SEAT=coo S4E_DONE_WHEN_RUN=1 bash -c "source \"$L\"; one_runner_guard test_x_suite.sh \"$CORPUS/tests/rebus/ALL.reb\"" 2>&1); r1c=$?
ck "1c the lane owner the LANES line names (coo, CEO-1342) passes under its own done: the loop's rows are written through done too" '[ "$r1c" = 0 ]'

echo "--- ARM 2: the harness guard refuses the same way ---"
o2=$(cd "$ROOT" && S4E_SEAT=cto S4E_DONE_WHEN_RUN=1 python3 -c "import sys; sys.path.insert(0, '../harness/scripts'); import corpus_suite_harness as h; h._one_runner_guard('$CORPUS/tests/rebus/ALL.reb', '$CORPUS', 'rebus')" 2>&1); r2=$?
ck "2 rc 2, the same sentence, the same helper named" '[ "$r2" = 2 ] && grep -q "DONE RUNS NO BOARD FOR ANY SEAT" <<<"$o2" && grep -q "util_suite_row_at_or_after.sh" <<<"$o2"'

echo "--- ARM 3: util_suite_row_at_or_after.sh reads the row a DONE-WHEN cites instead of running a board ---"
mkdir -p "$W/home/.github"; git -C "$ROOT" worktree add --detach "$W/home/SCRIP" HEAD >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage SCRIP as a worktree"; exit 2; }
NEW=$(git -C "$ROOT" rev-parse --short HEAD); OLD=$(git -C "$ROOT" rev-parse --short HEAD~3)
printf '# scratch suite table\nkey\tnick\temoji\tlang\tfirst_date\tfirst_pass\tfirst_total\ttoday_date\ttoday_pass\ttoday_total\ttree\tcriterion_changed\ttoday_excluded\nreb-rungs\tRebM\tx\trebus\t2026-09-03\t15\t48\t2026-09-28\t43\t43\t%s\t\t\n' "$NEW" > "$W/home/.github/SUITES.tsv"
o3a=$(S4E_HOME="$W/home" bash "$RA" reb-rungs "$OLD" 2>&1); r3a=$?
ck "3a a landing at HEAD~3 with the row measured on HEAD: rc 0, the row printed AT OR AFTER" '[ "$r3a" = 0 ] && grep -q "SUITE_ROW reb-rungs 43/43" <<<"$o3a" && grep -q "AT OR AFTER" <<<"$o3a"'
printf '# scratch suite table\nkey\tnick\temoji\tlang\tfirst_date\tfirst_pass\tfirst_total\ttoday_date\ttoday_pass\ttoday_total\ttree\tcriterion_changed\ttoday_excluded\nreb-rungs\tRebM\tx\trebus\t2026-09-03\t15\t48\t2026-09-28\t43\t43\t%s\t\t\n' "$OLD" > "$W/home/.github/SUITES.tsv"
o3b=$(S4E_HOME="$W/home" bash "$RA" reb-rungs "$NEW" 2>&1); r3b=$?
ck "3b a landing at HEAD with the row measured on HEAD~3: rc 1, BEFORE, wait for the loop (never run the board)" '[ "$r3b" = 1 ] && grep -q "BEFORE" <<<"$o3b" && grep -q "never run the board" <<<"$o3b"'
o3c=$(S4E_HOME="$W/home" bash "$RA" no-such-key "$NEW" 2>&1); r3c=$?
ck "3c an unknown key refuses rc 2" '[ "$r3c" = 2 ]'
o3d=$(S4E_HOME="$W/home" bash "$RA" reb-rungs 0000000 2>&1); r3d=$?
ck "3d a tree git cannot resolve refuses rc 2" '[ "$r3d" = 2 ]'

echo "--- ARM 4: the exemption census names a live baton whose DONE-WHEN runs a board (class BOARD) ---"
mkdir -p "$W/po/tasks"; printf '# gate fixture\n0\tt-board-row\thq_icon\tFREE\n0\tt-clean-row\thq_icon\tFREE\n' > "$W/po/QUEUE.tsv"
printf '# TASK t-board-row\nGOAL: fixture.\nDONE-WHEN: cd "$S4E_HOME/SCRIP" && bash ../harness/scripts/test_icon_jcon_suite.sh | grep -q m3_pass\nLINKS: none\n## LEDGER\n' > "$W/po/tasks/t-board-row.task.md"
printf '# TASK t-clean-row\nGOAL: fixture.\nDONE-WHEN: cd "$S4E_HOME/SCRIP" && bash ../harness/scripts/util_suite_row_at_or_after.sh jcon HEAD\nLINKS: none\n## LEDGER\n' > "$W/po/tasks/t-clean-row.task.md"
o4=$(S4E_TASKS="$W/po/tasks" S4E_QUEUE="$W/po/QUEUE.tsv" python3 "$XC" 2>&1); r4=$?
ck "4a the board-running baton is named (rc 1) with class BOARD" '[ "$r4" = 1 ] && grep -q "t-board-row" <<<"$o4" && grep -qE "BOARD" <<<"$o4"'
ck "4b the row-reading baton is not named" '! grep -q "t-clean-row" <<<"$o4"'

echo "--- ARM 5: FAIL-ONCE -- the old exemption planted back into a copy of the guard admits the run ---"
sed 's/printf .⛔ REFUSE(2) DONE RUNS NO BOARD FOR ANY SEAT[^;]*; return 2; fi/printf "ONE-RUNNER: exempt (planted)\\n"; return 0; fi/' "$L" > "$W/lib_planted.sh"
grep -q 'exempt (planted)' "$W/lib_planted.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the plant found no anchor in lib_one_runner.sh -- the refusal line moved; re-anchor the plant"; gate_stamp; exit 2; }
o5=$(S4E_SEAT=cto S4E_DONE_WHEN_RUN=1 bash -c "source \"$W/lib_planted.sh\"; one_runner_guard test_x_suite.sh \"$CORPUS/tests/rebus/ALL.reb\"" 2>&1); r5=$?
ck "5 with the exemption planted back the run is admitted rc 0 -- the defect this gate exists to see" '[ "$r5" = 0 ] && grep -q "exempt (planted)" <<<"$o5"'

echo "------------------------------------------------------------"
echo "population: $n check(s): both guards under S4E_DONE_WHEN_RUN=1 on the real rebus rungs path (no board run), the row reader over a scratch table against real trees $OLD..$NEW, the exemption census over a 2-baton scratch postoffice, one planted exemption"
if [ "$fails" -eq 0 ]; then echo "GATE PASS [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1
