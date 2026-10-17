#!/usr/bin/env bash
# lib_fanout.sh -- THE FAN-OUT CEILING (ceo CEO-1333, 2026-09-27 17:2x CDT, on the cfo's CFO-173 economy ask; Lon's ECONOMY word of
# 2026-09-07 binds every seat). MEASURED CAUSE: load 52.6 on 16 cores at 17:05 -- hq_templates 14 parallel compiles, hq_snocone's parser
# census at 12-13 scrip processes, hq_prolog's callgrind beside a census -- and every other seat's proofs ran five times slower (a cold
# build 166 s against 33 s, preflight 68 s against 13 s). THE RULE: a seat that fans out reads the machine's CPU demand FIRST and caps its
# concurrent children at max(2, min(4, cores - demand)); a census or sweep over hundreds of programs runs SERIALLY under nice -n 19; a long
# single job (callgrind, a monitor run, a cold build) is one child.
# ⛔ THE DEMAND IS NEVER load1 (ceo CEO-1394, the coo's COO-241 measurement): at 2026-10-01 15:00 CDT load1 read 1219 while PSI cpu read
# 3 percent -- three SCRIP Icon programs held 8k to 16k co-expression pthreads each -- and every fan-out on the box collapsed to width 2 on
# an idle machine. load1 counts threads, not demand. The demand is CPUs' worth of waiting: /proc/pressure/cpu "some avg10" (the percent of
# the last 10 s in which a runnable task waited for a CPU) times cores / 100, or, on a kernel without PSI, /proc/stat procs_running less
# the reader itself. Only the input changed; the shape stands.
#
# Source it (`. "$HERE/lib_fanout.sh"`) and use:
#   fanout_width   -> the number of concurrent children this seat may start now (2..4)
#   fanout_nice    -> the prefix for a serial census: "nice -n 19"
#   fanout_demand  -> the CPU demand it read, in CPUs (or FANOUT_TEST_LOAD, the planted-input seam for the gates)
#   fanout_source  -> which reading the demand came from: planted, pressure, procs_running or none
#   fanout_load1   -> the 1-minute load, REPORTED beside the demand and never read by the width
#   fanout_cores   -> nproc
#   fanout_report  -> one line naming all of them, for a runner's banner
# FANOUT_PROC (default /proc) is the root the three files are read under, so a gate can plant a whole machine.
# Or run it: `bash ../harness/scripts/lib_fanout.sh width|nice|demand|source|load|cores|report` (what a python runner or a Makefile shells out to).
# The python mirror is ../harness/scripts/lib_fanout.py (fanout_width()); test_gate_fanout_ceiling.sh and
# test_gate_fanout_width_reads_cpu_pressure_not_load1.sh hold the two in agreement.
fanout_cores() { nproc 2>/dev/null || echo 1; }
fanout_source() {
    local p="${FANOUT_PROC:-/proc}"
    if [ -n "${FANOUT_TEST_LOAD:-}" ]; then echo planted
    elif grep -qs '^some .*avg10=' "$p/pressure/cpu"; then echo pressure
    elif grep -qs '^procs_running ' "$p/stat"; then echo procs_running
    else echo none; fi
}
fanout_demand() {
    local p="${FANOUT_PROC:-/proc}"
    case "$(fanout_source)" in
        planted)       printf '%s\n' "$FANOUT_TEST_LOAD" ;;
        pressure)      awk -v c="$(fanout_cores)" '/^some / { for (i = 2; i <= NF; i++) if ($i ~ /^avg10=/) { sub(/^avg10=/, "", $i); printf "%.2f\n", c * $i / 100; exit } }' "$p/pressure/cpu" ;;
        procs_running) awk '/^procs_running / { n = $2 - 1; if (n < 0) n = 0; print n; exit }' "$p/stat" ;;
        *)             echo 0 ;;
    esac
}
fanout_load1() { local p="${FANOUT_PROC:-/proc}"; if [ -r "$p/loadavg" ]; then cut -d' ' -f1 "$p/loadavg"; else echo 0; fi; }
fanout_width() { awk -v d="$(fanout_demand)" -v c="$(fanout_cores)" 'BEGIN { w = int(c - d); if (w > 4) w = 4; if (w < 2) w = 2; print w }'; }
fanout_nice() { printf 'nice -n 19\n'; }
fanout_report() { printf 'FANOUT demand=%s (%s) cores=%s width=%s load1=%s (reported, never read) serial="%s" (CEO-1333/1394: max(2, min(4, cores - demand)); a census runs serially under nice 19)\n' "$(fanout_demand)" "$(fanout_source)" "$(fanout_cores)" "$(fanout_width)" "$(fanout_load1)" "$(fanout_nice)"; }
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        width) fanout_width ;; nice) fanout_nice ;; demand) fanout_demand ;; source) fanout_source ;; load) fanout_load1 ;; cores) fanout_cores ;; report) fanout_report ;;
        *) echo "usage: lib_fanout.sh width|nice|demand|source|load|cores|report (or source it)"; exit 2 ;;
    esac
fi
