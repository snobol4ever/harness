#!/usr/bin/env bash
# util_batch.sh -- THE BATCH CLASS (the cto, ARCH-SHARED-DEVELOPMENT 4.5 (b) and 5, R-2041 step 4; built by the cfo 2026-10-31).
# A batch job (an identity run, a census, a compile-all sweep, a callgrind, a placement-watch kick, a port HQ's board regrade, the
# DONE-WHEN sweep) runs ONLY through this wrapper, and a script that is batch by nature calls it at its own top:
#     [ -n "${S4E_BATCH_HELD:-}" ] || exec bash "$HERE/util_batch.sh" bash "$0" "$@"
# THE CLASS: the job runs in its own memory scope under s4e-batch.slice (CPUWeight 100, MemoryMax 12G on the slice), the scope
# bounded at 8192 MB with no swap and OOMPolicy=continue (util_mem_scope.py enter --kind batch, so a cgroup kill is a refusal, rc 2,
# never a red), inside one run slot of the box-wide pool (util_run_slot.sh, the seat's share first). The kernel gives batch what
# the sessions and the grader leave: about nine percent of a busy box, the whole of an idle one. No nice: a nice value is
# relative inside one cgroup and invisible across them (4.1).
# THE RULES:
#   - ONE BATCH JOB PER SEAT: a second top-level batch job of the same seat (lib_slots.sh s4e_slot_seat) REFUSES rc 2 and names
#     the holder; /tmp/s4e-batch/<seat>.lock is held by flock for the job's life and carries the holder's pid and command.
#   - NESTED, IT ENTERS NOTHING: inside a batch job S4E_BATCH_HELD=1 is exported, so a batch script a batch job starts (the
#     DONE-WHEN sweep running a gate that runs a census) runs in the job's own scope, as a nested runner finds its mem scope.
#   - INSIDE A QUIET SLICE IT REFUSES rc 2: a clock measurement must not share the box with a batch job (S4E_IN_SLICE).
#   - UNDER A HELD RUN SLOT IT TAKES NO SECOND ONE (4.6): util_run_slot.sh passes straight through on S4E_RUN_SLOT_HELD.
#   - UNDER THE GRADER IT ENTERS NOTHING (the cto, chunk 2, 2026-10-31): a gate the coo's loop runs (S4E_CLASS=grader) that calls a batch
#     script (the dyn-caps census, a sweep) runs it in the grader's own scope; the grader is its own class (4.5 (a)), and its four
#     tests at once would otherwise collide on the one-per-seat lock.
#   - S4E_BATCH_REPORT=FILE: once inside the scope the wrapper appends "BATCH_CGROUP <cgroup path>" to FILE before it runs the
#     command; test_gate_batch_scripts_run_in_the_batch_slice.sh reads it.
# usage: bash util_batch.sh CMD [ARG]...      (rc: the command's, or 2 when refused)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "${1:-}" = --inside ]; then
  shift
  [ -z "${S4E_BATCH_REPORT:-}" ] || printf 'BATCH_CGROUP %s\n' "$(sed -n 's/^0:://p' /proc/self/cgroup)" >> "$S4E_BATCH_REPORT"
  exec "$@"
fi
[ $# -ge 1 ] || { echo "usage: util_batch.sh CMD [ARG]..." >&2; exit 2; }
[ -z "${S4E_IN_SLICE:-}" ] || { echo "⛔ REFUSE(2) util_batch.sh: inside a quiet slice -- a batch job must not share a clock measurement's box (ARCH-SHARED-DEVELOPMENT 5)" >&2; exit 2; }
[ -z "${S4E_BATCH_HELD:-}" ] || exec "$@"
[ "${S4E_CLASS:-}" != grader ] || { export S4E_BATCH_HELD=grader; exec "$@"; }   # the grader is its own class: the job runs unwrapped, and HELD is set so a self-wrapping script runs once (hq_zetas 2026-11-04: without it, 13 scripts exec-looped forever under loop8)
. "$HERE/lib_slots.sh" || { echo "⛔ REFUSE(2) util_batch.sh: lib_slots.sh unloadable" >&2; exit 2; }
seat="$(s4e_slot_seat)"
lockdir="${S4E_BATCH_LOCK_DIR:-/tmp/s4e-batch}"
mkdir -p "$lockdir" 2>/dev/null || { echo "⛔ REFUSE(2) util_batch.sh: cannot make $lockdir" >&2; exit 2; }
lock="$lockdir/$seat.lock"
exec {S4E_BATCH_FD}<>"$lock" || { echo "⛔ REFUSE(2) util_batch.sh: cannot open $lock" >&2; exit 2; }
if ! flock -n "$S4E_BATCH_FD"; then
  echo "⛔ REFUSE(2) util_batch.sh: seat $seat already runs a batch job (one per seat, ARCH-SHARED-DEVELOPMENT 4.5): $(tr '\n' ' ' < "$lock" | cut -c1-300)" >&2
  exit 2
fi
: > "$lock"; printf 'pid=%s cmd=%s\n' "$$" "$*" > "$lock"
export S4E_BATCH_HELD=1
exec bash "$HERE/util_run_slot.sh" python3 "$HERE/util_mem_scope.py" enter --kind batch --slice s4e-batch.slice -- bash "$HERE/util_batch.sh" --inside "$@"
