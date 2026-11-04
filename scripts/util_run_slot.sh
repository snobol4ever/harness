#!/usr/bin/env bash
# util_run_slot.sh <command> <args>... -- AN AD-HOC RUN TAKES ONE OF THE BOX'S RUN SLOTS (Lon 2026-10-30, in-chat to the ceo, verbatim: "let's get
# the machine here not to be overloaded currently." · "Yes, do try your suggestions to fix the load problems."; ceo CEO-2033). Measured at 09:4x
# CDT: load 27 on 16 cores while the box's pools sat nearly idle (1 of 8 compile slots, 2 of 8 run slots), because the heavy runs bypassed them:
# a seat's own before-and-after binaries, a second scrip run started by hand, a compile-all sweep. The harness takes a run slot for every child it
# starts (corpus_suite_harness.py:_run_slot, CEO-1894); this wrapper takes the SAME slot locks under /tmp/s4e-run-slots for a run a seat starts
# itself, so hand runs and harness runs share one pool of S4E_RUN_SLOTS (default 8). It waits when every slot is held (rescanning every slot twice a second,
# never queued on one: a serial script holding a slot for hours pinned a waiter 17 minutes, 10-30) and execs the command with
# the lock on fd 8 for the command's whole life (the kernel frees it when the process exits, so a killed run frees its slot). A run already under
# a harness slot (S4E_RUN_SLOT_HELD set) takes no second one.
#   bash ../harness/scripts/util_run_slot.sh ./scrip prog.sno < /dev/null
#   bash ../harness/scripts/util_run_slot.sh ./old.bin -d64m
[ "$#" -gt 0 ] || { echo "usage: util_run_slot.sh <command> <args>... | util_run_slot.sh --bg [--probe] <command> <args>..." >&2; exit 2; }
# --bg (box-scheduler step 22): the command runs under setsid with S4E_BG_HANDLE=<id> in its environment, stdout and stderr in /tmp/s4e/<seat>/bg/<id>.log, and
# a handle file <id>.handle beside it (pid, seat, start, cwd, command); it prints `BG handle=<id> pid=<pid> log=<path>`. s4e_kill_mine.sh --handle <id> stops it.
if [ "$1" = --bg ]; then
    shift; . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_slots.sh"; _seat="$(s4e_slot_seat)"; _d="/tmp/s4e/$_seat/bg"; _probe=""
    [ "${1:-}" = --probe ] && { _probe=1; shift; set -- sleep 300; }
    [ "$#" -gt 0 ] || { echo "usage: util_run_slot.sh --bg [--probe] <command> <args>... (DESIGN-PLAN box-scheduler step 22: a background run has a handle)" >&2; exit 2; }
    mkdir -p "$_d" || { echo "REFUSE(2) [run_slot --bg]: cannot make $_d"; exit 2; }
    _id="$(date -u +%Y%m%dT%H%M%SZ)-$$"; _log="$_d/$_id.log"; _h="$_d/$_id.handle"
    S4E_BG_HANDLE="$_id" setsid bash "${BASH_SOURCE[0]}" "$@" > "$_log" 2>&1 < /dev/null & _pid=$!
    printf 'pid=%s seat=%s started=%s cwd=%s cmd=%s\n' "$_pid" "$_seat" "$(date -u +%FT%TZ)" "$PWD" "$*" > "$_h"
    if [ -n "$_probe" ]; then
        _why=""; sleep 1; kill -0 "$_pid" 2>/dev/null || _why="$_why the handle's pid is not alive;"
        tr '\0' '\n' < "/proc/$_pid/environ" 2>/dev/null | grep -qx "S4E_BG_HANDLE=$_id" || _why="$_why the pid does not carry the handle in its environment;"
        [ -s "$_h" ] && [ -e "$_log" ] || _why="$_why no handle or log file under $_d;"
        kill "$_pid" 2>/dev/null; wait "$_pid" 2>/dev/null; rm -f "$_h" "$_log"
        [ -z "$_why" ] && { echo "BG handle=$_id pid=$_pid log=$_log (probe: a run started under setsid with its handle in its environment, a handle and a log under $_d, then stopped)"; exit 0; }
        echo "BG PROBE RED:$_why"; exit 1
    fi
    echo "BG handle=$_id pid=$_pid log=$_log"; exit 0
fi
[ -n "${S4E_RUN_SLOT_HELD:-}" ] && exec "$@"
# SINCE 2026-10-31 (the cto, ARCH-SHARED-DEVELOPMENT 4.3, CEO-2041 step 3) THE RULE LIVES IN lib_slots.sh: a seat file first (cap S4E_RUN_SEAT_CAP, default 3), then a pool slot;
# S4E_CLASS=grader takes no seat file and may take any slot, every other taker leaves the top S4E_RUN_GRADER_RESERVED (2) slots to the grader.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_slots.sh"
s4e_slot_hold run; _rc=$?; [ "$_rc" = 2 ] && exit 2; [ "$_rc" = 0 ] || exec "$@"
s4e_slot_note run "$S4E_SLOT_T0" "$@"
exec "$@"
