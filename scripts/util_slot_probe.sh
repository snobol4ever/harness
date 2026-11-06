#!/usr/bin/env bash
# util_slot_probe.sh -- THE PROBE OF DESIGN-PLAN fleet-queue step 18 (run as: util_run_slot.sh --probe-sem): ADMISSION to the compile and run classes is GNU sem from a class table, with a timeout.
# It PROVES the live mechanism through the REAL taker, util_run_slot.sh --admit <class>, on a scratch sem home and scratch flock directories (S4E_SEM_HOME, S4E_RUN_SLOT_DIR and S4E_CC_SLOT_DIR under a mktemp
# dir; the live pools are never touched), at SCALED caps (compile pool 2, run 3 of which 1 is the grader's, seat share 1: the chain, the reservation, the seat share and the timeout are code paths, the table's caps are data,
# and the scaled run is a tenth of the perl startups), and only then prints one line per class from SLOTS.tsv, the table the taker reads:
#   SLOT by=sem class=<compile|run> id=<id> cap=<n> timeout_s=<n>
# What each plant shows: (1) a seat at its share is REFUSED rc 2 inside the bound and nothing runs; (2) a full compile pool refuses another seat; (3) an ordinary run is refused when the seats' pool is full while the
# grader is still admitted, to the grader's own pool; (4) that pool refuses a second grader take; (5) an admission holds exactly TWO sems (the seat's and the pool's, never a third: the cio's ruling); (6) a holder killed
# (SIGKILL, a pid this probe started) frees its admission and a waiter then runs; (7) an admission under S4E_RUN_SLOT_HELD opens no pool; (8) every refusal is one SLOT_WAITS line.
# rc 0 every plant holds and the lines are printed, 1 a plant is red (SLOT PROBE RED: names it, no SLOT line), 2 cannot measure (no sem).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_slots.sh"
command -v "${S4E_SEM:-sem}" > /dev/null || { echo "REFUSE(2) [slot probe]: no GNU sem on PATH (apt: parallel)"; exit 2; }
[ -n "$(s4e_slot_row compile 3)" ] && [ -n "$(s4e_slot_row run 3)" ] || { echo "REFUSE(2) [slot probe]: no compile or run row in ${S4E_SLOTS_TABLE:-$S4E_SLOTS_TABLE_DEFAULT}"; exit 2; }
T="$(mktemp -d "/tmp/s4e/$(s4e_slot_seat)/slotprobe.XXXXXX" 2> /dev/null || mktemp -d /tmp/s4e_slotprobe.XXXXXX)" || { echo "REFUSE(2) [slot probe]: no scratch dir"; exit 2; }
PIDS=""
cleanup() { local p; for p in $PIDS; do kill "$p" 2> /dev/null; done; wait 2> /dev/null; rm -rf "$T"; }
trap cleanup EXIT
TBL="$(s4e_slot_row compile 3)/$(s4e_slot_row run 3)"
export S4E_SEM_HOME="$T/sem" S4E_RUN_SLOT_DIR="$T/run" S4E_CC_SLOT_DIR="$T/cc" S4E_SLOT_WAITS="$T/waits.tsv" S4E_CC_SLOTS=2 S4E_CC_SEAT_CAP=1 S4E_RUN_SLOTS=3 S4E_RUN_SEAT_CAP=1 S4E_RUN_GRADER_RESERVED=1
unset S4E_RUN_SLOT_HELD S4E_CLASS S4E_ADMITTED
red=""
held() { local f c=0 p; for f in "$S4E_SEM_HOME"/semaphores/id-"$1"/*@*; do [ -e "$f" ] || continue; p="${f##*/}"; p="${p%%@*}"; kill -0 "$p" 2> /dev/null && c=$((c + 1)); done; echo "$c"; }
await() {   # <id> <n> -- up to 90 s for at least n live holders of the sem
    local i=0; while [ "$(held "$1")" -lt "$2" ] && [ "$i" -lt 180 ]; do sleep 0.5; i=$((i + 1)); done; [ "$(held "$1")" -ge "$2" ]
}
hold_bg() {   # <seat> <class|""> <compile|run> -- an admitted command that holds until killed; the pid is this probe's own
    S4E_SEAT="$1" S4E_CLASS="$2" bash "$HERE/util_run_slot.sh" --admit "$3" sleep 120 &
    PIDS="$PIDS $!"; LASTPID=$!
}
refused() {   # <label> <seat> <class|""> <compile|run> -- an admission that must be REFUSED rc 2 inside the bound with nothing run
    local out rc
    out="$(S4E_SEAT="$2" S4E_CLASS="$3" S4E_SLOT_WAIT_MAX=4 timeout -k 2 40 bash "$HERE/util_run_slot.sh" --admit "$4" echo RAN 2>&1)"; rc=$?
    { [ "$rc" = 2 ] && ! printf '%s' "$out" | grep -q '^RAN$'; } || red="$red $1:rc$rc"
}
hold_bg f1 "" compile; await s4e-compile 1 || red="$red compile:the-first-holder-never-held"
refused "compile-seat-share" f1 "" compile
hold_bg f2 "" compile; await s4e-compile 2 || red="$red compile:the-second-seat-never-held"
refused "compile-pool-full" f3 "" compile
hold_bg r1 "" run; R1=$LASTPID; hold_bg r2 "" run; await s4e-run-seats 2 || red="$red run:two-ordinary-never-held"
[ "$(held s4e-run-seat-r1)" = 1 ] && [ "$(held s4e-run)" = 0 ] && [ "$(held s4e-run-grader)" = 0 ] || red="$red run:an-admission-holds-other-than-seat-and-pool"
refused "run-seats-pool-full" r3 "" run
hold_bg g1 grader run; await s4e-run-grader 1 || red="$red run:the-grader-was-not-admitted-to-its-own-pool"
refused "run-grader-pool-full" g2 grader run
kill -9 "$R1" 2> /dev/null; wait "$R1" 2> /dev/null
out="$(S4E_SEAT=r4 S4E_SLOT_WAIT_MAX=40 timeout -k 2 60 bash "$HERE/util_run_slot.sh" --admit run echo RAN 2>&1)"; rc=$?
{ [ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^RAN$'; } || red="$red run:a-killed-holders-admission-stayed-held(rc$rc)"
mkdir -p "$T/nested"; S4E_SEM_HOME="$T/nested" S4E_RUN_SLOT_HELD=1 bash "$HERE/util_run_slot.sh" --admit run true
[ -z "$(ls "$T/nested" 2> /dev/null)" ] || red="$red run:a-nested-admission-opened-the-pool"
[ "$(grep -c 'admit-refused' "$T/waits.tsv" 2> /dev/null)" -ge 4 ] || red="$red waits:fewer-than-4-refusals-recorded($(grep -c 'admit-refused' "$T/waits.tsv" 2> /dev/null))"
if [ -n "$red" ]; then echo "SLOT PROBE RED:$red"; exit 1; fi
for c in compile run; do printf 'SLOT by=sem class=%s id=%s cap=%s timeout_s=%s\n' "$c" "$(s4e_slot_row "$c" 2)" "$(s4e_slot_row "$c" 3)" "$(s4e_slot_row "$c" 4)"; done
echo "SLOT PROBE ok: seat share, pool cap, the grader's own pool, two sems at most, kill frees, nested admission and timeout refusals proven through util_run_slot.sh --admit on a scratch sem home at scaled caps (cc 2, run 3 with 1 the grader's, seat 1); the lines above are SLOTS.tsv's (caps $TBL)"
exit 0
