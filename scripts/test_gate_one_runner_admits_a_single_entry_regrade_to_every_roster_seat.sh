#!/usr/bin/env bash
# test_gate_one_runner_admits_a_single_entry_regrade_to_every_roster_seat.sh -- ONE ENTRY IS A LANDER'S RE-GRADE, NOT A BOARD (the cto's ruling
# to the coo, 2026-11-01 09:5x CST, on hq_icon's fault: S4E_CHUNK=entry:progs/adlfirst bash test_icon_ipl_suite.sh refused rc 2 under ONE RUNNER,
# ONE BOARD, so a language HQ could not re-grade the one program its row names when it lives only in a package container; R-1342 as amended
# by R-1893/1926). Hermetic, ~1 s: a fixture MODE under S4E_POST (ROSTER and LANES lines), the guard called from bash -c (no mem scope, no
# binary fingerprint, no corpus). DETECTOR arms: an HQ the lane does not name, and an HQ of another language, are admitted with S4E_CHUNK naming
# ONE entry -- rc 0, the SINGLE ENTRY line naming the seat and the entry, the progress table a scratch file in the seat's own /tmp/s4e/<seat>
# (lib_one_runner places TMPDIR from S4E_SEAT; never the live table; the gate removes each one it causes)
# and S4E_SCORE_NO_WRITE set. CONTROL arms: two entries, a chunk, no chunk, a glob, an @resume, a seat off the ROSTER and the design officer
# are still refused rc 2; the lane owner is admitted by its lane with nothing redirected (its one-entry grading keeps writing the record).
# rc 0 every arm as expected; rc 1 an arm read wrong; rc 2 cannot measure.
set -u
H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; L="$H/lib_one_runner.sh"; G=one_runner_admits_a_single_entry_regrade_to_every_roster_seat
[ -r "$L" ] || { echo "⛔ GATE REFUSE(2) [$G]: $L missing"; exit 2; }
T=$(mktemp -d /tmp/s4e-single-entry-gate.XXXXXX) || { echo "⛔ GATE REFUSE(2) [$G]: no scratch directory"; exit 2; }; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/post/claims" "$T/tmp"
printf 'TENET\n# fixture MODE for %s\nROSTER: cto cfo coo cao cqo hq_icon hq_prolog\nLANES: icon=coo prolog=coo snobol4=coo\n' "$G" > "$T/post/MODE"
guard() {   # guard <seat> <chunk or -> : the guard on an icon package runner; prints rc=, db=, nw= after its own output
  env -u S4E_DONE_WHEN_RUN -u S4E_ONE_RUNNER_OVERRIDE -u S4E_ONE_RUNNER_FIXTURE -u S4E_PROGRESS_DB -u S4E_SCORE_NO_WRITE -u S4E_CHUNK \
    S4E_POST="$T/post" S4E_SEAT="$1" TMPDIR="$T/tmp" S4E_BIN_AT_START=fixture S4E_MEM_OOM_AT_START=0 S4E_MEM_SCOPE=unbounded \
    bash -c 'L="$1"; c="$2"; [ "$c" = - ] || export S4E_CHUNK="$c"; source "$L"; one_runner_guard test_icon_ipl_suite.sh; r=$?; printf "rc=%s db=%s nw=%s\n" "$r" "${S4E_PROGRESS_DB:-}" "${S4E_SCORE_NO_WRITE:+set}"' - "$L" "$2" 2>&1
}
fail=0; n=0
arm() {   # arm <name> <seat> <chunk> <want_rc> <must_match> [must_not_match]
  local out db; n=$((n + 1)); out="$(guard "$2" "$3")"
  db=$(printf '%s' "$out" | sed -n 's/^rc=[0-9]* db=\([^ ]*s4e-single-entry\.[A-Za-z0-9]*\) .*/\1/p'); [ -n "$db" ] && rm -f "$db"   # the scratch table the guard made, in the seat's own /tmp/s4e/<seat> (lib_one_runner places TMPDIR from S4E_SEAT)
  local one; one=$(printf '%s' "$out" | tr '\n' ' ' | sed 's/ $//')   # the guard's lines and the rc line as one, so a pattern can span them
  if printf '%s' "$one" | grep -F "rc=$4 " > /dev/null && printf '%s' "$one" | grep -E -- "$5" > /dev/null && { [ -z "${6:-}" ] || ! printf '%s' "$one" | grep -E -- "$6" > /dev/null; }; then echo "  ok   ARM $n: $1"
  else echo "  RED  ARM $n: $1 -- wanted rc=$4 and /$5/${6:+ and not /$6/}:"; printf '%s\n' "$out" | sed 's/^/         /' | cut -c1-220 | head -4; fail=1; fi
}
arm "DETECTOR: hq_icon (not icon's lane owner) re-grades ONE entry: admitted, scratch table under TMPDIR, no score row" hq_icon entry:progs/adlfirst 0 "SINGLE ENTRY, not a board -- seat hq_icon re-grades progs/adlfirst on test_icon_ipl_suite.sh.*db=(/tmp/s4e/hq_icon|$T/tmp)/s4e-single-entry\.[A-Za-z0-9]+ nw=set"
arm "DETECTOR: an HQ of another language (hq_prolog) on the icon runner is admitted for one entry too (every ROSTER seat)"  hq_prolog entry:progs/adlfirst 0 "SINGLE ENTRY, not a board -- seat hq_prolog"
arm "CONTROL: two entries stay a board and are refused"                       hq_icon "entry:a,entry:b" 2 "ONE RUNNER, ONE BOARD" "SINGLE ENTRY"
arm "CONTROL: a chunk stays a board and is refused"                           hq_icon chunk:01 2 "ONE RUNNER, ONE BOARD" "SINGLE ENTRY"
arm "CONTROL: no chunk at all stays a board and is refused"                   hq_icon - 2 "ONE RUNNER, ONE BOARD" "SINGLE ENTRY"
arm "CONTROL: a glob is not one entry and is refused"                         hq_icon "entry:progs/*" 2 "ONE RUNNER, ONE BOARD" "SINGLE ENTRY"
arm "CONTROL: an @resume cell is not one entry and is refused"                hq_icon "entry:a@b" 2 "ONE RUNNER, ONE BOARD" "SINGLE ENTRY"
arm "CONTROL: a seat off the ROSTER is refused one entry"                     ghost entry:progs/adlfirst 2 "ONE RUNNER, ONE BOARD" "SINGLE ENTRY"
arm "CONTROL: the design officer is still refused (R-2029 stands above the arm)" cto entry:progs/adlfirst 2 "A DESIGN OFFICER RUNS NO TESTS" "SINGLE ENTRY"
arm "CONTROL: the lane owner is admitted by its lane, nothing redirected (its grading keeps writing the record)" coo entry:progs/adlfirst 0 "rc=0 db= nw=$" "SINGLE ENTRY"
[ "$n" -gt 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: no arm ran"; exit 2; }
echo "SINGLE_ENTRY_ADMISSION_BOARD arms=$n red=$fail (harness $(git -C "$H/.." rev-parse --short HEAD 2>/dev/null || echo ?))"
if [ "$fail" = 0 ]; then echo "GATE PASS(0) [$G]: $n arms -- one entry is admitted to every ROSTER seat with no live progress line and no score row; two entries, a chunk, no chunk, a glob, an @resume, a seat off the ROSTER and the design officer stay refused"; exit 0; fi
echo "GATE FAIL(1) [$G]: see the RED arms"; exit 1
