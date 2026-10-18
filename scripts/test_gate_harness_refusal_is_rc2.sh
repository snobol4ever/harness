#!/usr/bin/env bash
# test_gate_harness_refusal_is_rc2.sh -- THE ACCEPTANCE GATE for row harness-refusal-exit-code-unified-on-rc-2
# (ceo CEO-233 -> hq_T 2026-09-04, minted on hq_T's own receipt: two refusal codes in one harness).
#
# THE DEFECT: corpus_suite_harness.py's refuse() exited rc=3 by this file's own local convention, while
# lib_gate.sh's three-code ladder and every bash gate say a refusal is rc=2 -- 0 measured-and-clean · 1
# measured-and-red · 2 COULD NOT MEASURE. It became untenable when the stale-binary preflight landed IN the
# harness (row harness-and-ladder-runner-refuse-on-a-stale-binary-...) and correctly exited 2: one tool then
# carried TWO refusal codes, so no caller could ask "did it refuse?" without knowing which refusal it hit.
#
# ⛔ THE POINT OF THIS GATE IS THAT rc=1 MUST NOT MOVE. Unifying refusals downward onto 2 is one edit away from
# collapsing "could not measure" into "measured and red", which is the false-green this whole harness exists to
# prevent -- so ARM 3 grades a REAL suite with a REAL red and asserts rc=1 survives, and ARM 4 asserts a clean
# suite still exits 0. A gate that only proved "refusals are 2" would pass on a harness that returned 2 for
# everything.
#
# ARMS: 1 behavioural refusal (missing suite file) -> rc=2 · 2 the source carries ZERO sys.exit(3) arms and
# refuse() exits 2 · 3 a red board still exits 1 (the distinction that must survive) · 4 a clean run still
# exits 0 · 5 the staleness refusal, which was already 2, is unchanged -- both refusal paths now agree.
# ⛔⭐ CEO-547 PART 2 (cto, 2026-09-11): arms 4, 6, 7, 8 and 9 graded the corpus rungs itself, so ONE RUNNER, ONE
# BOARD (CEO-523) refused each of them rc=2 on every seat but the coo -- THIS GATE was why `make test` was red for
# twelve of thirteen seats, and two of the five arms read GREEN off that wrong rc. Every grading arm now runs on
# this gate's own fixtures under $W, outside the corpus tree, and the two arms that could not distinguish one
# rc=2 from another assert what the refusal SAYS. Arm 4's rc check was also dead code (a line-continuation
# detached its `else`), which is why the banner claimed 16 checks and 15 ran; it is 23 now (arm 10, coo CEO-839).
# ⭐ ARMS 6-9 ADDED 2026-09-10 (hq_T, row corpus-suite-harness-run-without-lang-silently-regrades-...): a suite
# pair whose suffix names a dialect REFUSES rc=2 without --lang, in `run` AND in `pin-ref`, and the refusal names
# the flag instead of accusing the corpus · the explicit `--lang snobol4` escape hatch still reaches the
# line-per-entry reader · and a .sno pair with no --lang is untouched, which is the arm that catches a guard
# written too wide (it would red the SNOBOL4 rungs for the whole fleet).
# EXIT: 0 all arms · 1 an arm failed · 2 REFUSED (no python3/harness/rungs, or an unbuilt tree).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
. "$HERE/lib_board_line.sh"      # board_field/board_is: a board is read BY NAME, never by adjacency (CEO-839)
H="$HERE/corpus_suite_harness.py"
RUNGS="$S4E/corpus/tests/rebus"
[ -f "$H" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: harness not found at $H"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE rc=2: python3 not on PATH"; exit 2; }
[ -f "$RUNGS/ALL.reb" ] && [ -f "$RUNGS/ALL.ref" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: rebus rungs absent at $RUNGS -- arms 3/4 cannot distinguish a red board from a refusal"; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_gate_harness_refusal_is_rc2 >/dev/null 2>&1 || {
    echo "⛔ REFUSED-TO-GRADE rc=2: this tree's binary is stale or unbuilt -- arms 3/4 run real programs. Run 'make'."; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_rc2.XXXXXX")" || { echo "⛔ REFUSED-TO-GRADE rc=2: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
# ⛔⭐ EVERY GRADING ARM BELOW RUNS ON THIS GATE'S OWN FIXTURES, NEVER ON THE CORPUS RUNGS ITSELF (cto, 2026-09-11,
# CEO-547 part 2, on the ceo's ruling that make test was red for twelve of thirteen seats). ONE RUNNER, ONE BOARD
# (CEO-523) refuses a run whose POPULATION is under the corpus tree to any seat but the coo, and arms 4, 6, 7, 8 and
# 9 each pointed at a real rungs -- so on every seat but the coo they collected a ONE-RUNNER rc=2 instead of the
# behaviour they claim to grade. ⛔ TWO OF THEM READ **GREEN** ON THAT WRONG RC, which is the false green this gate
# exists to prevent: arm 5 asserted only `rc=2` and the one-runner refusal is also 2, and arm 8 asserted only that
# the words `has suffix` were absent, which they are in a refusal that never reached the suffix check. Both now
# assert what the refusal SAYS, not merely its code. The fixtures are byte copies of the real rebus rungs (so arm
# 3's red is still a real graded failure of a real suite) written OUTSIDE the corpus tree, where the guard
# correctly judges them not a board: $W/clean is the unmutated pair, $W/red carries the injected mismatch, $W/sno
# is a two-entry SNOBOL4 pair for arm 9. The cost is unchanged -- this gate graded the rebus rungs twice before
# and still does.
mkdir -p "$W/clean" "$W/red" "$W/sno" || { echo "⛔ REFUSED-TO-GRADE rc=2: cannot build fixtures under $W"; exit 2; }
python3 - "$RUNGS" "$W" <<'FIXTURES' || { echo "⛔ REFUSED-TO-GRADE rc=2: fixture build failed"; exit 2; }
import sys, pathlib
m, w = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
src, ref = (m/'ALL.reb').read_text(), (m/'ALL.ref').read_text()
(w/'clean'/'ALL.reb').write_text(src)
(w/'clean'/'ALL.ref').write_text(ref)
(w/'red'/'ALL.reb').write_text(src)
(w/'red'/'ALL.ref').write_text(ref.replace('\n', '\nZZZ-DELIBERATE-MISMATCH\n', 1))
for extra in ('ALL.csv','ALL.in','ALL.xfail','ALL.wantrc','ALL.modes'):
    if (m/extra).is_file():
        t = (m/extra).read_text()
        (w/'clean'/extra).write_text(t); (w/'red'/extra).write_text(t)
(w/'sno'/'ALL.sno').write_text(" OUTPUT = 'AB' 'CD';END;* gate_rc2_fixture_1\n OUTPUT = 2 + 3;END;* gate_rc2_fixture_2\n")
(w/'sno'/'ALL.ref').write_text("ABCD\n5\n")
(w/'sno'/'ALL.csv').write_text("entry,modes\ngate_rc2_fixture_1,m3\ngate_rc2_fixture_2,m3\n")
FIXTURES
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: the suite harness has ONE refusal code, and it is rc=2 ==="
echo "--- ARM 1: a refusal (missing suite file) exits rc=2, not rc=3 AND NOT rc=1 ---"
# ⛔ THIS ARM FOUND A LIVE DEFECT ONE LAYER BELOW THE ROW: a missing ALL.<ext>/ALL.ref reached Path.read_text()
# and died with a FileNotFoundError TRACEBACK, which Python exits 1 for -- and rc=1 here means "ran fine, some
# entries are RED". The case where NOTHING was graded returned the code for a measured red board. Cured in
# cmd_run with an existence check ahead of every reader; this arm keeps it dead. ⭐ Note the ceo's own DONE-WHEN
# for this row used `--lang snobol4`, which argparse REJECTS (snobol4 is spelled as the empty default), so it
# exited 2 from argparse and read GREEN on a harness that was still crashing. A behavioural arm has to name a
# form the tool actually accepts, or it grades the argument parser.
out="$(timeout -k 5 60 python3 "$H" run "$W/none.reb" "$W/none.ref" --lang rebus --modes m3,m4 2>&1)"; rc=$?
[ "$rc" = 2 ] && ck ok "missing suite file -> rc=2" || ck no "must REFUSE rc=2; got rc=$rc -- $(head -c 300 <<<"$out")"
grep -q 'REFUSING' <<<"$out" && ck ok "the refusal says so on stderr" || ck no "refusal not announced -- $(head -c 300 <<<"$out")"
echo "--- ARM 2: the source carries no exit-3 arm at all ---"
n=$(grep -c 'sys.exit(3)' "$H")
[ "$n" = 0 ] && ck ok "zero sys.exit(3) arms in the harness" || ck no "$n sys.exit(3) arm(s) remain -- the second refusal code is still there"
grep -qE '^\s*sys\.exit\(2\)' <<<"$(sed -n '/^def refuse/,/^def /p' "$H")" && ck ok "refuse() itself exits 2" || ck no "refuse() does not exit 2"
echo "--- ARM 3 (the distinction that must survive): a RED board still exits 1, never 2 ---"
# ⛔ Built from the REAL rungs so the red is a real graded failure, not a synthetic one: one entry whose ref is
# deliberately wrong. A harness that returned 2 for everything would pass every other arm of this gate.
out="$(timeout -k 5 300 python3 "$H" run "$W/red/ALL.reb" "$W/red/ALL.ref" --lang rebus --modes m3,m4 2>&1)"; rc=$?
[ "$rc" = 1 ] && ck ok "a graded board with a red exits 1 (could-not-measure did not swallow measured-and-red)" \
              || ck no "a red board must exit 1; got rc=$rc -- $(tail -c 300 <<<"$out")"
echo "--- ARM 4: a clean graded run still exits 0 or 1 by its board, never a refusal ---"
# ⛔ THIS ARM'S rc CHECK WAS DEAD CODE UNTIL 2026-09-11 (cto). It was written
#     if [ ... ]; then ck ok "..." \
#     else ck no "..."; fi
# and the trailing backslash joined the two lines, so `else ck no "..."` became four more ARGUMENTS to `ck ok`
# and the `if` had no else branch at all: on the failing path -- the only path that matters -- NOTHING RAN and
# NOTHING WAS COUNTED. The gate's own banner said 16 checks while it only ever performed 15, which is how it
# went unseen. A check that cannot fail is an instrument reporting success while doing nothing (RULES.md THE
# INSTRUMENT LAWS); it is written on one line now so no continuation can detach it again.
out="$(timeout -k 5 300 python3 "$H" run "$W/clean/ALL.reb" "$W/clean/ALL.ref" --lang rebus --modes m3,m4 2>&1)"; rc=$?
if [ "$rc" = 0 ] || [ "$rc" = 1 ]; then ck ok "a clean rungs pair grades and returns a board verdict (rc=$rc), not a refusal"; else ck no "a runnable rungs must not refuse; got rc=$rc -- $(tail -c 300 <<<"$out")"; fi
grep -qiE 'suite_board' <<<"$out" && ck ok "the run printed its board" || ck no "no board printed -- $(tail -c 300 <<<"$out")"
echo "--- ARM 5: the staleness refusal (already 2) agrees -- BOTH refusal paths now return one code ---"
# ⛔ rc=2 ALONE CANNOT IDENTIFY WHICH REFUSAL FIRED, and that is exactly how this arm read green for months on
# every seat but the coo: it was pointed at the corpus rungs, the ONE-RUNNER guard refused it first with its own
# rc=2, and the assertion could not tell the two apart. The arm now names the refusal it is grading.
cp "$ROOT/scrip" "$W/scrip.old"; touch -d "2020-01-01T00:00:00" "$W/scrip.old"
out="$(SCRIP="$W/scrip.old" timeout -k 5 120 python3 "$H" run "$W/clean/ALL.reb" "$W/clean/ALL.ref" --lang rebus --modes m3,m4 2>&1)"; rc=$?
[ "$rc" = 2 ] && ck ok "the staleness refusal is rc=2, same code as every other refusal" || ck no "staleness refusal got rc=$rc -- $(tail -c 300 <<<"$out")"
grep -qiE 'stale|older than|rebuild|run .make.' <<<"$out" && ck ok "and it is THE STALENESS refusal, not some other rc=2" || ck no "rc=2 arrived from a refusal that never mentions staleness -- $(head -c 300 <<<"$out")"
echo "--- ARM 6: a corpus suite pair whose suffix names a dialect REFUSES rc=2 without --lang ---"
# ⛔⭐ ROW corpus-suite-harness-run-without-lang-silently-regrades-the-suite-one-entry-per-line-instead-of-refusing
# (minted by the cfo 2026-09-08 from two live near-misses; cured by hq_T 2026-09-10). --lang is what selects the
# comment syntax that DELIMITS ENTRIES. Omitted, `run` fell back to the SNOBOL4 `*`-banner grammar, which over a
# .pas/.reb rungs parses EVERY SOURCE LINE as its own entry -- a different population -- and then reported
# failures about that imaginary population with total confidence: `family.ref is shorter than family.sno at seq
# 904` for a pascal pair whose ALL.pas and ALL.ref BOTH carry 251 markers, and `declarations with no matching
# entry` naming four rebus entries that DO exist. ⛔ BOTH MESSAGES ACCUSE THE DATA, so the reader is sent to edit
# a corpus that is fine -- the cfo was one step from filing two rung suites as unrunnable. THE DEFECT WAS THE SILENT
# FALLBACK, NOT THE MISSING FLAG.
out="$(timeout -k 5 120 python3 "$H" run "$W/clean/ALL.reb" "$W/clean/ALL.ref" --modes m3 2>&1)"; rc=$?
[ "$rc" = 2 ] && ck ok "a .reb pair with no --lang REFUSES rc=2 instead of regrading line-per-entry" \
              || ck no "must REFUSE rc=2; got rc=$rc -- $(tail -c 300 <<<"$out")"
grep -qi -- '--lang' <<<"$out" && ck ok "the refusal names the flag the reader must pass" \
                              || ck no "refused without naming --lang, so the reader cannot act on it -- $(head -c 300 <<<"$out")"
grep -qiE 'shorter than|no matching entry' <<<"$out" && ck no "the refusal still carries the data-accusing wording" \
                                                     || ck ok "the refusal blames the READER, not the corpus"
echo "--- ARM 7: pin-ref carries the same guard (it REWRITES the pair from what it read) ---"
# pin-ref is the worse of the two callers: a pin rewrites the whole pair from whatever the reader thought it read,
# so a mis-chosen grammar there does not merely misreport, it EDITS the corpus into the misreading.
out="$(timeout -k 5 120 python3 "$H" pin-ref "$W/clean/ALL.reb" "$W/clean/ALL.ref" nosuchentry --ruling "gate probe, no --apply" 2>&1)"; rc=$?
[ "$rc" = 2 ] && ck ok "pin-ref on a .reb pair with no --lang REFUSES rc=2" || ck no "pin-ref must REFUSE rc=2; got rc=$rc -- $(tail -c 300 <<<"$out")"
grep -qi -- '--lang' <<<"$out" && ck ok "pin-ref's refusal names the flag" || ck no "pin-ref refused without naming --lang -- $(head -c 300 <<<"$out")"
echo "--- ARM 8: the line-per-entry reader stays REACHABLE when asked for explicitly ---"
# ⭐ THE CURE MUST NOT REMOVE A CAPABILITY, only stop it being reached BY ACCIDENT. `--lang snobol4` is an
# accepted synonym of the default, so it must still select the SNOBOL4 grammar on any suffix -- explicit is a
# choice, blank is an accident, and only the accident is refused. Whatever this run does, it must NOT be the
# suffix refusal: the escape hatch being silently closed would look identical to the cure working.
# ⛔ ASSERTING ONLY THAT `has suffix` IS ABSENT IS NOT ENOUGH: it is absent from EVERY refusal that never reached
# the suffix check, so on a corpus path this arm read green off a ONE-RUNNER rc=2 that proved nothing about the
# escape hatch. It must witness the SNOBOL4 grammar actually being reached, so it grades the .sno-shaped reader
# over a .reb pair and asserts the run got as far as reading entries by that grammar.
out="$(timeout -k 5 120 python3 "$H" run "$W/clean/ALL.reb" "$W/clean/ALL.ref" --lang snobol4 --modes m3 2>&1)"; rc=$?
grep -qi 'has suffix' <<<"$out" && ck no "--lang snobol4 was refused by the suffix guard -- the explicit escape hatch is gone" \
                                || ck ok "--lang snobol4 still selects the SNOBOL4 grammar deliberately (rc=$rc)"
grep -qiE 'one runner|is a board' <<<"$out" && ck no "this arm never reached the grammar -- it collected a ONE-RUNNER refusal, the false green CEO-547 part 2 removed" \
                                            || ck ok "and it reached the reader rather than an unrelated refusal"
echo "--- ARM 9: a .sno pair with no --lang is UNTOUCHED (every existing caller) ---"
# The census before the cure: every `harness run` invocation in ../harness/scripts/ that omits --lang passes a .sno pair.
# This arm is the one that would catch a guard written too wide -- it would red the SNOBOL4 rungs for the fleet.
# ⛔ THE POPULATION HERE IS THE GATE'S OWN TWO-ENTRY .sno PAIR, not a shard of the SNOBOL4 rungs (cto 2026-09-11):
# the claim is that the SUFFIX guard does not fire on .sno, and a two-entry pair witnesses that exactly as well as
# 1/40 of 3832 while grading something this gate owns. ⛔ AND IT MUST ACTUALLY GRADE: the board line is checked for
# m3_n=2 as well as for existing, because a run that graded NOTHING also prints a SUITE_BOARD and also exits 0.
out="$(timeout -k 5 300 python3 "$H" run "$W/sno/ALL.sno" "$W/sno/ALL.ref" --modes m3 2>&1)"; rc=$?
if [ "$rc" = 0 ] || [ "$rc" = 1 ]; then ck ok "a .sno pair still grades with no --lang (rc=$rc)"
else ck no "the guard caught a .sno caller -- got rc=$rc -- $(tail -c 300 <<<"$out")"; fi
# ⛔⭐ THIS ARM READ THE BOARD BY POSITION AND WAS RED FOR A DAY OVER A CORRECT BOARD (ceo CEO-839, coo's
# row instruments-rc2-gate-arm9-...): it grepped '^SUITE_BOARD family=ALL total=2 m3_n=2 ', which asserts
# that NOTHING sits between total= and m3_n=, and SCRIP 3ade619f2 (CEO-749/772) correctly put shipped= and
# outside= there.  It then reported the failure as "no board over the 2 entries" -- reading like the run
# graded nothing rather than like the pattern was stale, which is why nothing caught it: this is a make test
# arm, not a preflight arm.  It now reads each field BY NAME through lib_board_line.sh, so a board that adds
# a field stays green and a board that grades nothing still reds.  util_board_field_matcher_census.py counts
# every remaining positional matcher in ../harness/scripts/ and arm 10 below holds it at zero.
_b9="$(grep -m1 '^SUITE_BOARD ' <<<"$out")"
if [ -n "$_b9" ] && board_is "$_b9" family ALL && board_is "$_b9" total 2 && board_is "$_b9" m3_n 2; then
  ck ok "and it printed a board that graded both entries, not an empty one (family/total/m3_n read BY NAME: family=$(board_field "$_b9" family) total=$(board_field "$_b9" total) m3_n=$(board_field "$_b9" m3_n))"
else
  ck no "no board over the 2 entries -- family=$(board_field "$_b9" family) total=$(board_field "$_b9" total) m3_n=$(board_field "$_b9" m3_n) -- $(head -c 240 <<<"$_b9")"
fi
echo "--- ARM 10: the arm-9 predicate itself -- planted boards, and the positional-matcher census at zero ---"
# ⛔ AN ARM THAT ONLY PASSES PROVES NOTHING ABOUT WHAT IT REJECTS.  Arm 9's cure is "read the fields by name",
# and the two things that must both hold are planted here directly on the predicate: a board that GRADED
# NOTHING still reds (the property arm 9 was added for), and a board that gained a field between total= and
# m3_n= is still accepted (the property it lost).  A gate cured by loosening its pattern would pass the second
# and fail the first; this arm makes that impossible to land quietly.
_plant_ok="SUITE_BOARD family=ALL total=2 shipped=2 outside=0 brand_new_field=7 m3_n=2 m3_pass=2 m3_fail=0"
_plant_empty="SUITE_BOARD family=ALL total=2 shipped=2 outside=0 m3_n=0 m3_pass=0 m3_fail=0"
if board_is "$_plant_ok" family ALL && board_is "$_plant_ok" total 2 && board_is "$_plant_ok" m3_n 2; then
  ck ok "(10a) a board carrying a FIELD THIS GATE HAS NEVER SEEN between total= and m3_n= is still accepted -- the exact insertion that broke arm 9"
else ck no "(10a) an inserted field still breaks the reading -- the cure did not anchor on identity"; fi
if board_is "$_plant_empty" m3_n 2; then
  ck no "(10b) a board that graded NOTHING (m3_n=0) was accepted -- the cure loosened the arm instead of re-anchoring it"
else ck ok "(10b) a board that graded nothing (m3_n=0) still REDS -- arm 9 kept the property it was added for"; fi
if board_field "$_plant_empty" no_such_field >/dev/null 2>&1; then
  ck no "(10c) an ABSENT field read as present -- absence and zero would be indistinguishable"
else ck ok "(10c) an absent field is rc=1, not the empty string standing in for 0"; fi
_cen="$(python3 "$HERE/util_board_field_matcher_census.py" 2>&1)"; _crc=$?
_cadj="$(sed -n 's/^CENSUS board-matchers ADJACENT=\([0-9]*\) .*/\1/p' <<<"$_cen" | head -1)"
if [ "$_crc" = 0 ] && [ "${_cadj:-x}" = 0 ]; then
  ck ok "(10d) the positional-matcher census over ../harness/scripts/ prints its population and reads ADJACENT=0: $(grep -m1 '^CENSUS board-matchers literals' <<<"$_cen" | cut -c1-150)"
else
  ck no "(10d) positional board matchers remain (rc=$_crc, ADJACENT=${_cadj:-unreadable}) -- $(grep -m2 'ADJACENT-MATCHER' <<<"$_cen" | tr '\n' ';' | cut -c1-220)"
fi
if ! python3 "$HERE/util_board_field_matcher_census.py" --selftest >/dev/null 2>&1; then
  ck no "(10e) the census's own selftest does not pass -- an uninstrumented census is a grep that agrees"
else ck ok "(10e) the census trips on planted patterns and tells a PRINTER from a MATCHER (its own selftest)"; fi
echo "------------------------------------------------------------"
if [ "$fails" -ne 0 ]; then echo "⛔ GATE FAIL: $fails of $checks check(s) failed"; exit 1; fi
echo "✅ GATE PASS: $checks/$checks checks"; exit 0
