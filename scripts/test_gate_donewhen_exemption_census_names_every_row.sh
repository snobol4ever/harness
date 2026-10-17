#!/usr/bin/env bash
# test_gate_donewhen_exemption_census_names_every_row.sh -- THE DONE-WHEN EXEMPTION CENSUS, PINNED BOTH WAYS (ceo CEO-967, on the coo's
# COO-116 report; row instruments-the-donewhen-exemption-census-names-every-criterion-that-measures-its-one-runner-exemption). The bus
# runs every computed DONE-WHEN under S4E_DONE_WHEN_RUN=1, a ONE-RUNNER exemption, so a criterion that runs the guard or a guarded
# runner can be measuring the exemption rather than its subject. util_donewhen_exemption_census.py names each such baton with its owner,
# its mechanism and its class (GUARD, BOARD) and counts the ones that clear the exemption (CLEAR).
# ARMS on a hermetic fixture tasks tree and QUEUE: (1) a live baton running a guarded board is named BOARD with its owner, and one reading
# the guard is named GUARD, rc 1; (2) a baton that clears the exemption first is counted CLEAR and never named; (3) a DONE baton is not
# named by default and is with --all; (4) the other direction: once both exposed criteria clear the exemption the census reads rc 0 with
# 0 exposed; (5) an unreadable tasks tree and an unreadable QUEUE each REFUSE rc 2, never a zero; (6) on the live postoffice it measures
# (rc 0 or 1) and prints its population beside the rc; (7) an AREA SMOKE the guard admits for every seat -- S4E_AREA_SMOKE_ENTRIES set
# non-empty on the command or exported before it, a runner in lib_one_runner.sh's ONE_RUNNER_SMOKE_MODE_RUNNERS, no population named --
# is counted SMOKE and never named, while a plain run of that runner, a smoke of a runner without a smoke mode, a smoke naming --corpus
# and a smoke beside another board stay BOARD (ceo CEO-1505: the census named hq_icon's closable IPL mask row; FAILED ONCE on the census
# before that landing, which read all six BOARD); (8) a census that cannot read the smoke-mode list REFUSES rc 2.
# ⛔ FAILED ONCE: before this landing there was no census, and the row's DONE-WHEN read "No such file".
# EXIT 0 every arm holds; 1 an arm is red; 2 REFUSED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; C="$HERE/util_donewhen_exemption_census.py"
[ -f "$C" ] || { echo "REFUSED(2): $C missing"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
mk() { mkdir -p "$T/tasks"; printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: %s\n## NEXT\nx\n' "$1" "$2" > "$T/tasks/$1.task.md"; }
mk exposed-board 'cd "$S4E_HOME/SCRIP" && bash ../harness/scripts/test_icon_jcon_suite.sh | grep -q "m3_pass=91"'
mk exposed-guard 'cd "$S4E_HOME/SCRIP" && bash ../harness/scripts/lib_one_runner.sh --check test_icon_jcon_suite.sh'
mk clear-board 'cd "$S4E_HOME/SCRIP" && env -u S4E_DONE_WHEN_RUN bash ../harness/scripts/test_icon_jcon_suite.sh'
mk plain-gate 'cd "$S4E_HOME/SCRIP" && bash ../harness/scripts/test_gate_our_files_are_lf.sh'
mk done-board 'cd "$S4E_HOME/SCRIP" && bash ../harness/scripts/test_icon_arizona_suite.sh'
printf '# fixture\n0\texposed-board\thq_icon\tFREE\n0\texposed-guard\tcoo\tASSIGNED:coo\n1\tclear-board\thq_icon\tFREE\n1\tplain-gate\tcoo\tFREE\n2\tdone-board\thq_icon\tDONE\n' > "$T/QUEUE.tsv"
run() { S4E_TASKS="$T/tasks" S4E_QUEUE="$T/QUEUE.tsv" python3 "$C" "$@"; }
out="$(run 2>&1)"; rc=$?
[ "$rc" = 1 ] && grep -qE '^  BOARD +hq_icon .*exposed-board +<- test_icon_jcon_suite\.sh' <<<"$out" && grep -qE '^  GUARD +coo .*exposed-guard +<- lib_one_runner\.sh' <<<"$out" \
  && grep -q 'exposed and LIVE: 2$' <<<"$out" && ck ok "(1) a live board criterion is named BOARD with its owner and a guard criterion GUARD, rc 1, 2 exposed" || ck no "(1) rc=$rc :: $(tr '\n' '|' <<<"$out" | cut -c1-300)"
! grep -q 'clear-board\|plain-gate' <<<"$out" && grep -q 'CLEAR 1;' <<<"$out" && ck ok "(2) a criterion that clears the exemption first is counted CLEAR and never named; a plain gate is not counted" || ck no "(2) $(tr '\n' '|' <<<"$out" | cut -c1-300)"
all="$(run --all 2>&1)"
! grep -q 'done-board' <<<"$out" && grep -qE 'BOARD +hq_icon +DONE .*done-board' <<<"$all" && ck ok "(3) a DONE baton is not named by default and is with --all" || ck no "(3) default/all: $(grep -c done-board <<<"$out")/$(grep -c done-board <<<"$all")"
mk exposed-board 'cd "$S4E_HOME/SCRIP" && env -u S4E_DONE_WHEN_RUN bash ../harness/scripts/test_icon_jcon_suite.sh | grep -q "m3_pass=91"'
mk exposed-guard 'cd "$S4E_HOME/SCRIP" && S4E_DONE_WHEN_RUN= bash ../harness/scripts/lib_one_runner.sh --check test_icon_jcon_suite.sh'
out4="$(run 2>&1)"; rc4=$?
[ "$rc4" = 0 ] && grep -q 'exposed and LIVE: 0$' <<<"$out4" && grep -q 'CLEAR 3;' <<<"$out4" && ck ok "(4) the other direction: once both criteria clear the exemption the census reads rc 0 with 0 exposed (CLEAR 3)" || ck no "(4) rc=$rc4 :: $(tail -1 <<<"$out4" | cut -c1-200)"
S4E_TASKS=/nonexistent-tasks-dir python3 "$C" --json > /dev/null 2>&1; r5a=$?
S4E_TASKS="$T/tasks" S4E_QUEUE=/nonexistent-queue.tsv python3 "$C" > /dev/null 2>&1; r5b=$?
[ "$r5a" = 2 ] && [ "$r5b" = 2 ] && ck ok "(5) an unreadable tasks tree and an unreadable QUEUE each REFUSE rc 2 -- never a dark zero" || ck no "(5) unreadable tasks rc=$r5a, unreadable QUEUE rc=$r5b"
live="$(python3 "$C" 2>&1)"; r6=$?
if [ "$r6" = 2 ]; then echo "⛔ REFUSED(2): the live postoffice could not be read: $(tail -1 <<<"$live" | cut -c1-160)"; exit 2; fi
{ [ "$r6" = 0 ] || [ "$r6" = 1 ]; } && grep -qE '^population: [1-9][0-9]* baton' <<<"$live" && ck ok "(6) on the live postoffice: $(tail -1 <<<"$live" | cut -c13-200) (rc $r6)" || ck no "(6) the live census: rc=$r6 $(tail -1 <<<"$live" | cut -c1-160)"
T7="$T/a7"; mkdir -p "$T7/tasks"
mk7() { printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: %s\n## NEXT\nx\n' "$1" "$2" > "$T7/tasks/$1.task.md"; printf '2\t%s\thq_icon\tFREE\n' "$1" >> "$T7/QUEUE.tsv"; }
: > "$T7/QUEUE.tsv"
mk7 smoke-ipl 'cd "$S4E_HOME/SCRIP" && S4E_AREA_SMOKE_ENTRIES="procs/hostname gprogs/when" timeout -k 5 600 bash ../harness/scripts/test_icon_ipl_suite.sh'
mk7 smoke-exported 'cd "$S4E_HOME/SCRIP" && export S4E_AREA_SMOKE_ENTRIES=agt_driver; bash ../harness/scripts/test_snobol4_gimpel_suite.sh'
mk7 plain-ipl 'cd "$S4E_HOME/SCRIP" && timeout -k 5 600 bash ../harness/scripts/test_icon_ipl_suite.sh'
mk7 smoke-nosmoke-runner 'cd "$S4E_HOME/SCRIP" && S4E_AREA_SMOKE_ENTRIES="x" bash ../harness/scripts/test_icon_jcon_suite.sh'
mk7 smoke-with-corpus 'cd "$S4E_HOME/SCRIP" && S4E_AREA_SMOKE_ENTRIES="agt_driver" bash ../harness/scripts/test_snobol4_gimpel_suite.sh --corpus ../corpus'
mk7 smoke-beside-board 'cd "$S4E_HOME/SCRIP" && S4E_AREA_SMOKE_ENTRIES="procs/hostname" bash ../harness/scripts/test_icon_ipl_suite.sh && bash ../harness/scripts/test_icon_arizona_suite.sh'
out7="$(S4E_TASKS="$T7/tasks" S4E_QUEUE="$T7/QUEUE.tsv" python3 "$C" 2>&1)"; rc7=$?
n7=$(grep -cE '^  BOARD +hq_icon .*(plain-ipl|smoke-nosmoke-runner|smoke-with-corpus|smoke-beside-board) ' <<<"$out7")
[ "$rc7" = 1 ] && [ "$n7" = 4 ] && ! grep -qE 'smoke-ipl|smoke-exported' <<<"$out7" && grep -q 'BOARD 4, SMOKE 2, CLEAR 0; exposed and LIVE: 4$' <<<"$out7" \
  && ck ok "(7) an admitted area smoke (set on the command, or exported) is counted SMOKE and never named; plain, no-smoke-mode, --corpus and beside-a-board stay BOARD" \
  || ck no "(7) rc=$rc7 named-BOARD=$n7 :: $(tr '\n' '|' <<<"$out7" | cut -c1-400)"
T9="$T/a9"; mkdir -p "$T9/tasks"; : > "$T9/QUEUE.tsv"
mk9() { printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: %s\n## NEXT\nx\n' "$1" "$2" > "$T9/tasks/$1.task.md"; printf '2\t%s\thq_prolog\tFREE\n' "$1" >> "$T9/QUEUE.tsv"; }
mk9 onefile-swi 'cd "$S4E_HOME/SCRIP" && out=$(timeout -k 5 1200 bash ../harness/scripts/test_prolog_swi_suite.sh --file core/test_arith.pl --modes m3,m4 2>&1); printf "%s" "$out" | grep -q "^SWI_BOARD"'
mk9 swi-without-file 'cd "$S4E_HOME/SCRIP" && bash ../harness/scripts/test_prolog_swi_suite.sh --modes m3'
mk9 file-on-a-runner-not-listed 'cd "$S4E_HOME/SCRIP" && bash ../harness/scripts/test_icon_jcon_suite.sh --file x.icn'
mk9 swi-file-with-corpus 'cd "$S4E_HOME/SCRIP" && bash ../harness/scripts/test_prolog_swi_suite.sh --file core/test_arith.pl --corpus ../corpus'
out9="$(S4E_TASKS="$T9/tasks" S4E_QUEUE="$T9/QUEUE.tsv" python3 "$C" 2>&1)"; rc9=$?
n9=$(grep -cE '^  BOARD +hq_prolog .*(swi-without-file|file-on-a-runner-not-listed|swi-file-with-corpus) ' <<<"$out9")
[ "$rc9" = 1 ] && [ "$n9" = 3 ] && ! grep -q 'onefile-swi' <<<"$out9" && grep -q 'ONEFILE 1, GUARD 0, BOARD 3, SMOKE 0, CLEAR 0; exposed and LIVE: 3$' <<<"$out9" \
  && ck ok "(9) a one-file run of a runner on lib_one_runner.sh's single-file list is counted ONEFILE and never named (CEO-1664); without --file, on a runner off the list, or naming --corpus it stays BOARD" \
  || ck no "(9) rc=$rc9 named-BOARD=$n9 :: $(tr '\n' '|' <<<"$out9" | cut -c1-400)"
mkdir -p "$T/nolib"; cp "$C" "$T/nolib/"
S4E_TASKS="$T7/tasks" S4E_QUEUE="$T7/QUEUE.tsv" python3 "$T/nolib/${C##*/}" > /dev/null 2>&1; r8=$?
[ "$r8" = 2 ] && ck ok "(8) a census beside no lib_one_runner.sh cannot read the smoke-mode list and REFUSES rc 2 -- never a guess" || ck no "(8) rc=$r8 with no lib_one_runner.sh beside the census"
echo "population: $checks arm(s) -- a 5-baton fixture both ways, two refusal shapes, the live tasks tree, a 6-baton area-smoke fixture and the smoke-list refusal"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [donewhen_exemption_census_names_every_row]: $checks of $checks arms hold"; exit 0; fi
echo "⛔ GATE FAIL(1) [donewhen_exemption_census_names_every_row]: $fails of $checks arms red"; exit 1
