#!/usr/bin/env bash
export S4E_DB_CHECK_OVERRIDE="gate fixture: this gate plants no progress rows (util_score_row.py db_crosscheck, hq_raku 2026-09-16)"
# test_gate_score_row_write_names_the_lane_owner_from_mode.sh -- THE SCORE-ROW WRITE PATH READS MODE's LANES: LINE, NAMES THE
# ADMITTED SEAT FOR THE BOARD'S LANGUAGE, AND REFUSES ANY OTHER SEAT BY NAME (coo 2026-09-16; ceo CEO-786; hq_snobol4's
# finding; row instruments-every-board-write-prints-one-runner-not-determined-under-no-central-runner-read-the-lanes-line).
#
# THE DEFECT: under CEO-775 (no central runner) util_score_row.py looked only for THE ONE RUNNER on MODE line 2, found none,
# printed "ONE RUNNER NOT DETERMINED ... If you are not the one runner, this row is yours to discard" to the seat that OWNS
# the row, and wrote -- while lib_one_runner.sh already admitted exactly the LANES: seat for the board's language.
#
# THE CURE UNDER TEST: lane_writer_seat(lang) reads the LANES: line the shell guard reads; one_runner_declines prints the
# admitted seat when the measurer is it, REFUSES by name (rc=0, non-fatal, byte-unchanged) when it is not, keeps the two doors (the bus's
# computed done run; a loud S4E_SCORE_WRITE -- ⛔ NOT S4E_ONE_RUNNER_OVERRIDE, which admits the board RUN and says nothing
# about publication since ceo CEO-961, 2026-09-20), and falls back to THE ONE RUNNER clause only when no LANES: line
# answers; the stale sentence is gone from the file.
#
# ARMS (a scratch .github that LOOKS like the shared board -- a git clone with an origin url -- because a plain scratch
# copy is exempt by design; a scratch MODE through S4E_MODE_FILE; the live .github is never touched):
#   (a) measurer = the LANES: owner writes its own language's board row: the write lands and names the lane owner
#   (b) measurer = another seat: REFUSED by name (both seats), SCORE.md byte-identical, NON-FATAL rc=0 (the standing ruling of test_gate_score_row_only_the_one_runner_writes.sh: a bookkeeping refusal never reds a measured board)
#   (c) S4E_ONE_RUNNER_OVERRIDE="why" does NOT open this door and says so by name (ceo CEO-961: it admits the RUN; a
#       control arm publishes nothing by default), and (c2) S4E_SCORE_WRITE="why" opens it loudly for that other seat
#   (d) no LANES: line and no ONE RUNNER clause: the honest fallback writes and says LANE OWNER NOT DETERMINED
#   (e) the stale sentence is absent from util_score_row.py and every lib_*.sh
# FAIL_ONCE=1 swaps arm (b)'s measurer for the lane owner so the expected refusal never comes, proving the arm trips.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; GH="$HERE/../../.github"; HELPER="$HERE/util_score_row.py"
. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh" || { echo "REFUSED(2): cannot load lib_suites_tsv.sh"; exit 2; }
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$HELPER" ] && [ -f "$GH/SCORE.md" ] && [ -f "$SUITES_TSV_REAL" ] && [ -f "$GH/scripts/util_suite_banner.py" ] || refuse "need $HELPER and the live .github files to copy"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_lane_owner.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/.github/scripts"; cp "$GH/SCORE.md" "$SUITES_TSV_REAL" "$W/.github/"; cp "$GH/scripts/util_suite_banner.py" "$W/.github/scripts/"
( cd "$W/.github" && git init -q && git add -A && git -c user.name=fixture -c user.email=f@x commit -q -m fixture && git remote add origin "file://$W/.github" ) || refuse "could not shape the scratch .github as a clone with an origin"
MODE="$W/MODE"; printf 'DECTET\n# fixture line 2 -- no THE ONE RUNNER here\nLANES: icon=hq_icon rebus=cfo\n' > "$MODE"
# the two doors are UNSET here on purpose: the bus's computed `done` runs this gate with S4E_DONE_WHEN_RUN=1 in its environment,
# and an inherited door would open the refusal arm (b) from outside the fixture (measured 2026-09-16: done rc=1 on this row)
w(){ export S4E_SEAT="$1"; env -u S4E_DONE_WHEN_RUN -u S4E_ONE_RUNNER_OVERRIDE -u S4E_SCORE_WRITE S4E_HOME="$W" S4E_MODE_FILE="$MODE" python3 "$HELPER" write --lang rebus --column board --modes m3,m4 --measurer "${S4E_SEAT:-}" --text 'rungs both-modes 43/43 · m3 43/43 FAIL=0 xfail=0 xpass=0 · m4 43/43 FAIL=0 SKIP=0 xfail=0 xpass=0 (gate fixture)' --suite-pass 43 --suite-total 43 "${@:2}" 2>&1; }
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: the score-row write names the lane owner from MODE LANES: and refuses any other seat (CEO-786) ==="
m0="$(md5sum < "$W/.github/SCORE.md")"; out="$(w cfo)"; rc=$?; m1="$(md5sum < "$W/.github/SCORE.md")"
[ "$rc" = 0 ] && [ "$m0" != "$m1" ] && grep -q 'lane owner: cfo writes rebus rows' <<<"$out" && ck ok "(a) the LANES: owner (cfo, rebus) writes its board row and the write names the lane owner" || ck no "(a) rc=$rc changed=$([ "$m0" != "$m1" ] && echo yes || echo no) -- got: $(grep -E 'lane owner|REFUSED|NOT UPDATED' <<<"$out" | head -2 | cut -c1-160)"
OTHER=coo; [ -n "${FAIL_ONCE:-}" ] && OTHER=cfo
m0="$(md5sum < "$W/.github/SCORE.md")"; out="$(w $OTHER)"; rc=$?; m1="$(md5sum < "$W/.github/SCORE.md")"
# rc=0 by the standing ruling of test_gate_score_row_only_the_one_runner_writes.sh arm 1 (a bookkeeping refusal never reds a measured board): named, byte-unchanged, non-fatal
[ "$rc" = 0 ] && [ "$m0" = "$m1" ] && grep -q 'seat coo is not cfo' <<<"$out" && grep -q 'lane owner' <<<"$out" && ck ok "(b) another seat (coo) writing a rebus row is REFUSED by name (both seats), SCORE.md byte-identical, non-fatal rc=0 per the standing ruling" || ck no "(b) rc=$rc identical=$([ "$m0" = "$m1" ] && echo yes || echo no) -- got: $(grep -E 'NOT UPDATED|lane owner|REFUSED' <<<"$out" | head -2 | cut -c1-200)"
export S4E_SEAT=coo
m0="$(md5sum < "$W/.github/SCORE.md")"
out="$(S4E_HOME="$W" S4E_MODE_FILE="$MODE" S4E_ONE_RUNNER_OVERRIDE='gate fixture: control arm for a landing, publishes nothing' env -u S4E_DONE_WHEN_RUN -u S4E_SCORE_WRITE python3 "$HELPER" write --lang rebus --column board --modes m3,m4 --measurer "${S4E_SEAT:-}" --text 'rungs both-modes 43/43 · m3 43/43 FAIL=0 xfail=0 xpass=0 · m4 43/43 FAIL=0 SKIP=0 xfail=0 xpass=0 (gate fixture)' --suite-pass 43 --suite-total 43 2>&1)"; rc=$?; m1="$(md5sum < "$W/.github/SCORE.md")"
[ "$rc" = 0 ] && [ "$m0" = "$m1" ] && grep -q 'admitted THE RUN, not the WRITE' <<<"$out" && grep -q 'S4E_SCORE_WRITE' <<<"$out" && ck ok "(c) S4E_ONE_RUNNER_OVERRIDE writes NOTHING (byte-identical) and names the consent it is not -- CEO-961 splits the run from the write" || ck no "(c) rc=$rc identical=$([ "$m0" = "$m1" ] && echo yes || echo no) -- got: $(grep -E 'OVERRIDE|NOT UPDATED|CONSENT' <<<"$out" | head -2 | cut -c1-200)"
out="$(S4E_HOME="$W" S4E_MODE_FILE="$MODE" S4E_SCORE_WRITE='gate fixture: the leaderboard write consent' env -u S4E_DONE_WHEN_RUN -u S4E_ONE_RUNNER_OVERRIDE python3 "$HELPER" write --lang rebus --column board --modes m3,m4 --measurer "${S4E_SEAT:-}" --text 'rungs both-modes 43/43 · m3 43/43 FAIL=0 xfail=0 xpass=0 · m4 43/43 FAIL=0 SKIP=0 xfail=0 xpass=0 (gate fixture)' --suite-pass 43 --suite-total 43 2>&1)"; rc=$?; m2="$(md5sum < "$W/.github/SCORE.md")"
[ "$rc" = 0 ] && [ "$m1" != "$m2" ] && grep -q 'LEADERBOARD WRITE CONSENT by coo' <<<"$out" && ck ok "(c2) S4E_SCORE_WRITE opens the leaderboard door loudly for the other seat" || ck no "(c2) rc=$rc changed=$([ "$m1" != "$m2" ] && echo yes || echo no) -- got: $(grep -E 'CONSENT|NOT UPDATED' <<<"$out" | head -2 | cut -c1-160)"
printf 'DECTET\n# fixture line 2 -- no THE ONE RUNNER, no LANES either\n' > "$MODE"
out="$(w coo)"; rc=$?
[ "$rc" = 0 ] && grep -q 'LANE OWNER NOT DETERMINED' <<<"$out" && ! grep -q 'yours to discard' <<<"$out" && ck ok "(d) no LANES: and no ONE RUNNER: the honest fallback writes and says LANE OWNER NOT DETERMINED (never 'yours to discard')" || ck no "(d) rc=$rc -- got: $(grep -E 'DETERMINED|NOT UPDATED' <<<"$out" | head -2 | cut -c1-160)"
grep -q 'ONE RUNNER NOT DETERMINED' "$HELPER" "$HERE"/lib_*.sh 2>/dev/null && ck no "(e) the stale sentence is still printed by an instrument" || ck ok "(e) the stale sentence 'ONE RUNNER NOT DETERMINED' is gone from util_score_row.py and every lib_*.sh"
echo "population: $checks arm(s) graded, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [score_row_write_names_the_lane_owner_from_mode]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [score_row_write_names_the_lane_owner_from_mode]: $fails of $checks arms FAIL"; exit 1
