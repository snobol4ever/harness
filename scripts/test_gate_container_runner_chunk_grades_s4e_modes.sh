#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)/scrip" || exit $?
# test_gate_container_runner_chunk_grades_s4e_modes.sh -- A CONTAINER PACKAGE RUNNER'S CHUNK ROAD GRADES THE MODES S4E_MODES NAMES, DEFAULT m3
# (CIO-7, Lon 2026-11-08 in the cio's window: "We will test mode 3 only until further notice."; officer_01's ruling 10:2x CST to officer_02 and the
# coo: lib_container_package_runner.sh's chunk line in container_package_run passes --modes "${S4E_MODES:-m3}", the form s4e_cycle.sh's run_cell
# uses; the whole-suite line is NOT touched, it writes the both-modes suite row). Found by the coo at harness 3e6d19a: test_icon_unicon_suite.sh
# with S4E_CHUNK=entry:<name> graded mode 4 beside mode 3, so every UniTests entry DONE-WHEN read mode 4 too.
# THE READING IS THE RUN, NEVER THE TEXT: the gate runs test_icon_unicon_suite.sh (the UniTests runner, whose body is container_package_run) on
# ONE graded entry, the first the harness's own list verb names, with S4E_PROGRESS_OFF=1 (no progress row) and reads the SUITE_BOARD line,
# which carries <m>_n= for exactly the modes the harness graded:
#   arm 1  S4E_MODES unset      -> m3_n=1 present, no m4_n=      (the default is mode 3 alone)
#   arm 2  S4E_MODES=m3,m4      -> m3_n=1 and m4_n=1 present     (the knob still opens mode 4)
# The entry's verdict is not read: a red entry grades its modes as surely as a green one.
# FAIL ONCE: arm 1 reads red on harness 6d7e5383 (the chunk line hard-codes --modes m3,m4: m4_n=1 with S4E_MODES unset).
# EXIT: 0 both arms hold; 1 an arm red, named; 2 refused (no runner, no container, no entry listed, no SUITE_BOARD, a population not one).
set -u
G=test_gate_container_runner_chunk_grades_s4e_modes
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"; SD="$ROOT/SCRIP"
PKG="$ROOT/corpus/packages/icon/unicon_tests"
[ -f "$HERE/test_icon_unicon_suite.sh" ] || { echo "⛔ REFUSE(2) [$G]: no test_icon_unicon_suite.sh beside the gate"; exit 2; }
[ -f "$PKG/ALL.icn" ] && [ -f "$PKG/ALL.ref" ] || { echo "⛔ REFUSE(2) [$G]: no container at $PKG/ALL.{icn,ref}"; exit 2; }
ENTRY="$(cd "$SD" && S4E_PROGRESS_OFF=1 timeout -k 5 120 python3 "$HERE/corpus_suite_harness.py" list "$PKG/ALL.icn" "$PKG/ALL.ref" --lang icon 2>/dev/null < /dev/null | head -1)"
[ -n "$ENTRY" ] || { echo "⛔ REFUSE(2) [$G]: corpus_suite_harness.py list named no graded entry of $PKG"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/$G.XXXXXX")"; trap 'rm -rf "$T"' EXIT
RED=0; NOTE=""
arm() {  # name, S4E_MODES value ("" = unset), want_m4 (0|1)
    local name="$1" modes="$2" want4="$3" board rc
    if [ -n "$modes" ]; then
        ( cd "$ROOT" && S4E_HOME="$ROOT" S4E_MODES="$modes" S4E_PROGRESS_OFF=1 S4E_CHUNK="entry:$ENTRY" S4E_ONE_RUNNER_OVERRIDE="$G: one entry, modes read, nothing recorded" \
            timeout -k 5 600 bash "$HERE/util_run_slot.sh" bash "$HERE/test_icon_unicon_suite.sh" ) > "$T/$name.log" 2>&1 < /dev/null; rc=$?
    else
        ( cd "$ROOT" && unset S4E_MODES && S4E_HOME="$ROOT" S4E_PROGRESS_OFF=1 S4E_CHUNK="entry:$ENTRY" S4E_ONE_RUNNER_OVERRIDE="$G: one entry, modes read, nothing recorded" \
            timeout -k 5 600 bash "$HERE/util_run_slot.sh" bash "$HERE/test_icon_unicon_suite.sh" ) > "$T/$name.log" 2>&1 < /dev/null; rc=$?
    fi
    board="$(grep -m1 '^SUITE_BOARD ' "$T/$name.log")"
    [ -n "$board" ] || { echo "⛔ REFUSE(2) [$G]: arm $name (rc $rc) printed no SUITE_BOARD line; its last lines:"; tail -5 "$T/$name.log"; exit 2; }
    grep -qE '(^| )m3_n=1( |$)' <<<"$board" || { echo "⛔ REFUSE(2) [$G]: arm $name graded no single m3 entry (population not one): ${board:0:200}"; exit 2; }
    if grep -qE '(^| )m4_n=' <<<"$board"; then
        [ "$want4" = 1 ] || { RED=$((RED + 1)); NOTE="$NOTE arm-$name:m4-graded-with-S4E_MODES-${modes:-unset}"; }
    else
        [ "$want4" = 0 ] || { RED=$((RED + 1)); NOTE="$NOTE arm-$name:no-m4-with-S4E_MODES=$modes"; }
    fi
}
arm unset "" 0
arm both m3,m4 1
echo "CONTAINER_RUNNER_CHUNK_MODES_BOARD entry=$ENTRY arms=2 red=$RED${NOTE:+ red_arms=$NOTE} (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"
[ "$RED" = 0 ] && { echo "GATE OK [$G]: the chunk road grades mode 3 alone by default and mode 4 only when S4E_MODES names it"; exit 0; }
echo "GATE FAIL [$G]:$NOTE"; exit 1
