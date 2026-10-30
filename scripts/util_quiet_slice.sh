#!/usr/bin/env bash
# util_quiet_slice.sh [--max S] <command> <args>... -- A RESERVED SLICE OF THE BOX FOR A CLOCK MEASUREMENT (Lon 2026-10-30, in-chat to the ceo,
# verbatim: "Yes, let's move on to performance for SNOBOL4 and Icon. But you'll have to work around the load problem. Maybe get reserved slices of
# the machine for short periods of time or just count INSTRUCTIONS and use system performance process information to help get around a fully loaded
# system."; ceo CEO-2035). THE FIRST TOOL IS THE COUNT: util_instr_count.sh (perf stat -e instructions:u, WORK and OVERHEAD, x against sbl) does not
# move with the load and runs at any time. A CLOCK is admissible only inside a slice: this script takes the box-wide slice lock (/tmp/s4e-slice.lock,
# so two slicers never split the pools between them and deadlock), then EVERY run slot (/tmp/s4e-run-slots, S4E_RUN_SLOTS) and EVERY compile slot
# (/tmp/s4e-cc-slots, S4E_CC_SLOTS) one by one, waiting for each holder to finish, so no harness child and no slotted compile starts while the
# command runs. It runs the command for at most --max seconds (default 300, ceiling 600), releases everything, and appends one line to
# /home/resources/progress/SLICES.tsv: start, seat, seconds waited, seconds held, the load average and busy cores at the start, rc, the command.
# BUILD BEFORE THE SLICE: a compile inside it would wait on a compile slot the slice itself holds. What it cannot drain: the Claude sessions themselves and any run started outside the pools (util_run_slot.sh is the road for those, CEO-2033).
# The load at the start is printed and recorded beside the clock so a reader can judge the slice; a clock taken at a load over half the cores is
# reported as such, never as a quiet measurement.
#   bash ../harness/scripts/util_quiet_slice.sh --max 120 bash ../harness/scripts/bench_triangulate_snobol4.sh ...
# EXIT: the command's rc; 2 = refused (no command, a bad --max, a slice taken inside a slice).
MAX=300
if [ "${1:-}" = "--max" ]; then MAX="${2:-}"; shift 2; fi
case "$MAX" in ''|*[!0-9]*) echo "util_quiet_slice.sh: --max needs whole seconds" >&2; exit 2;; esac
[ "$MAX" -le 600 ] || { echo "util_quiet_slice.sh: --max $MAX is over the 600 s ceiling; a slice is short by design" >&2; exit 2; }
[ "$#" -gt 0 ] || { echo "usage: util_quiet_slice.sh [--max S] <command> <args>..." >&2; exit 2; }
[ -z "${S4E_IN_SLICE:-}" ] || { echo "util_quiet_slice.sh: already inside a slice" >&2; exit 2; }
NR="${S4E_RUN_SLOTS:-8}"; NC="${S4E_CC_SLOTS:-8}"
RD=/tmp/s4e-run-slots; CD=/tmp/s4e-cc-slots; LOG=/home/resources/progress/SLICES.tsv
mkdir -p "$RD" "$CD" || exit 2
t0=$(date +%s)
exec 200>>/tmp/s4e-slice.lock || exit 2
flock 200
fd=201
i=0; while [ "$i" -lt "$NR" ]; do eval "exec $fd>>\"$RD/slot$i\""; flock "$fd"; fd=$((fd + 1)); i=$((i + 1)); done
i=0; while [ "$i" -lt "$NC" ]; do eval "exec $fd>>\"$CD/slot$i\""; flock "$fd"; fd=$((fd + 1)); i=$((i + 1)); done
t1=$(date +%s)
load=$(cut -d' ' -f1 /proc/loadavg); cores=$(nproc)
seat="$(basename "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)")"
echo "SLICE taken by $seat after $((t1 - t0)) s: load $load on $cores cores; every run and compile slot held for at most $MAX s" >&2
S4E_IN_SLICE=1 S4E_RUN_SLOT_HELD=1 timeout -k 5 "$MAX" "$@"
rc=$?
t2=$(date +%s)
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u -d @"$t1" +%Y-%m-%dT%H:%M:%SZ)" "$seat" "$((t1 - t0))" "$((t2 - t1))" "$load/$cores" "$rc" "$*" >> "$LOG" 2>/dev/null
echo "SLICE released after $((t2 - t1)) s, rc=$rc" >&2
exit "$rc"
