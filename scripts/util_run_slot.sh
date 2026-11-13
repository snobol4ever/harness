#!/usr/bin/env bash
# util_run_slot.sh <command> <args>... -- AN AD-HOC RUN TAKES ONE OF THE BOX'S RUN SLOTS (Lon 2026-10-30, in-chat, verbatim: "let's get
# the machine here not to be overloaded currently." · "Yes, do try your suggestions to fix the load problems."; R-2033). Measured at 09:4x
# CDT: load 27 on 16 cores while the box's pools sat nearly idle (1 of 8 compile slots, 2 of 8 run slots), because the heavy runs bypassed them:
# a seat's own before-and-after binaries, a second scrip run started by hand, a compile-all sweep. The harness takes a run slot for every child it
# starts (corpus_suite_harness.py:_run_slot, R-1894); this wrapper takes the SAME slot locks under /tmp/s4e-run-slots for a run a seat starts
# itself, so hand runs and harness runs share one pool of S4E_RUN_SLOTS (default 8; since fleet-queue step 18 GNU sem semaphores from SLOTS.tsv, see lib_slots.sh). It waits when every slot is held (rescanning every slot twice a second,
# never queued on one: a serial script holding a slot for hours pinned a waiter 17 minutes, 10-30) and execs the command with
# the lock on fd 8 for the command's whole life (the kernel frees it when the process exits, so a killed run frees its slot). A run already under
# a harness slot (S4E_RUN_SLOT_HELD set) takes no second one.
#   bash ../harness/scripts/util_run_slot.sh ./scrip prog.sno < /dev/null
#   bash ../harness/scripts/util_run_slot.sh ./old.bin -d64m
[ "$#" -gt 0 ] || { echo "usage: util_run_slot.sh <command> <args>... | util_run_slot.sh --bg [--probe] <command> <args>... | util_run_slot.sh --admit <compile|run> <command>... | util_run_slot.sh --probe-sem" >&2; exit 2; }
# --probe-sem (fleet-queue step 18): util_slot_probe.sh proves the sem pools on a scratch home through the real takers, then prints one `SLOT by=sem class=... id=... cap=... timeout_s=...` line per pool class of SLOTS.tsv.
[ "$1" = --probe-sem ] && exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_slot_probe.sh"
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
# --admit <compile|run> <command> (fleet-queue step 18, the cio 2026-11-05): ADMISSION to a class by GNU sem, for a take that is rare and long (a batch job, a build, a whole suite run, a landing); the seat's share, then the
# class pool (SLOTS.tsv; lib_slots.sh s4e_sem_admit). A run is then taken as any other (its flock slot below); a compile class runs the command on the admission alone. Skipped, silently, inside a held run slot or an
# admission already taken (S4E_ADMITTED): a nested take would wait on its own parent. The per-entry and per-compile slots stay flock (327 M instructions a sem take against 12-19 M; the coo and the cio ruled).
# --probe-cores (row one-core-budget-every-compile-and-run-takes-a-token-from-one-count): the proof of the one core budget on a scratch pool and a scratch CORES.conf (lib_slots.sh s4e_cores_probe); prints CORES probe ok
if [ "${1:-}" = --probe-cores ]; then . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_slots.sh"; s4e_cores_probe; exit $?; fi
if [ "$1" = --admit ]; then
    _class="${2:-}"; shift 2
    case "$_class" in compile|run|land) ;; *) echo "usage: util_run_slot.sh --admit <compile|run|land> <command> <args>..." >&2; exit 2;; esac
    [ "$#" -gt 0 ] || { echo "usage: util_run_slot.sh --admit <compile|run> <command> <args>..." >&2; exit 2; }
    if [ -z "${S4E_ADMITTED:-}" ] && [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
        . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_slots.sh"
        s4e_sem_admit "$_class"; _rc=$?; [ "$_rc" = 2 ] && exit 2
        s4e_slot_note "$_class-admit" "$S4E_SLOT_T0" "$@"
    fi
    case "$_class" in compile|land) exec "$@";; esac   # a compile or a landing runs on the admission alone (the landing's own runs take their flock slots below it)
fi
[ -n "${S4E_RUN_SLOT_HELD:-}" ] && exec "$@"
# SINCE 2026-10-31 (the cto, ARCH-SHARED-DEVELOPMENT 4.3, R-2041 step 3) THE RULE LIVES IN lib_slots.sh: a seat file first (cap S4E_RUN_SEAT_CAP, default 3), then a pool slot;
# S4E_CLASS=grader takes no seat file and may take any slot, every other taker leaves the top S4E_RUN_GRADER_RESERVED (2) slots to the grader.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_slots.sh"
s4e_slot_hold run; _rc=$?; [ "$_rc" = 2 ] && exit 2; [ "$_rc" = 0 ] || exec "$@"
s4e_slot_note run "$S4E_SLOT_T0" "$@"
exec "$@"
