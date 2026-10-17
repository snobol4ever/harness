#!/usr/bin/env bash
# util_perf_context.sh — SYS-PERF attribution for every measured number (Lon 2026-08-23, hq_C session, verbatim in
# substance: "all this measuring of wall clock speed on this one computer now running 19 claude sessions ... the
# benchmarks must do a CPU and wait time analysis for everything ... a shell process to always watch and report all
# the SYS PERF data to help deduce proper performance attribution").
#
# THE LAW THIS ENFORCES: a wall-clock number on a shared box is NOT a measurement unless it carries (a) the load
# context it ran under and (b) its own CPU-vs-wall split. user+sys ≈ wall = the program really computed that long;
# user+sys ≪ wall = it WAITED and the number belongs to the box, not the program. TIMEOUT-graded correctness
# verdicts need the same stamp: a genuine non-termination spins (user ≈ wall); a load-starved false TIMEOUT waits.
#
# Modes:
#   run <cmd...>     run cmd, then print one CONTEXT line + one ATTRIB line + a VERDICT (CPU-BOUND|WAIT-BOUND|MIXED)
#   watch [secs]     sample loop (default 5s): loadavg, cpu busy/iowait/steal %, runnable/total tasks, scrip+sbl
#                    process count, top-3 CPU hogs — for a Monitor or a background log beside a benchmark run
#   stamp            print the one-shot CONTEXT line (for embedding in harness output)
set -u
ctx() { read -r l1 l5 l15 rq _ < /proc/loadavg; rq="${rq%%/*}"
  nc=$(nproc); ns=$(pgrep -c scrip 2>/dev/null) || :; nb=$(pgrep -c sbl 2>/dev/null) || :; ns=${ns:-0}; nb=${nb:-0}
  echo "CONTEXT load1=$l1 load5=$l5 cores=$nc runnable=$rq scrip_procs=$ns sbl_procs=$nb"; }
cpusnap() { awk '/^cpu /{print $2+$3+$4+$6+$7+$8, $5, $6, $9}' /proc/stat; }
case "${1:-stamp}" in
  stamp) ctx;;
  run) shift; [ $# -gt 0 ] || { echo "usage: util_perf_context.sh run <cmd...>" >&2; exit 2; }
    ctx
    tf=$(mktemp); /usr/bin/time -f "%e %U %S" -o "$tf" "$@"; rc=$?
    read -r w u s < "$tf"; rm -f "$tf"
    v=$(awk -v w="$w" -v u="$u" -v s="$s" 'BEGIN{c=u+s; r=(w>0)?c/w:1; print (r>=0.85)?"CPU-BOUND":(r<=0.4)?"WAIT-BOUND":"MIXED"}')
    echo "ATTRIB wall=${w}s user=${u}s sys=${s}s rc=$rc verdict=$v"
    [ "$v" = WAIT-BOUND ] && echo "⛔ WAIT-BOUND: this wall-clock number belongs to the BOX, not the program — do not quote it, and do not grade a TIMEOUT from it."
    exit $rc;;
  watch) iv="${2:-5}"
    read -r b bi bw br <<< "$(cpusnap)"
    while :; do sleep "$iv"
      read -r a ai aw ar <<< "$(cpusnap)"
      d=$((a-b+ai-bi)); busy=0; iow=0; stl=0
      [ "$d" -gt 0 ] && { busy=$((100*(a-b)/d)); iow=$((100*(aw-bw)/d)); stl=$((100*(ar-br)/d)); }
      echo "$(date +%H:%M:%S) cpu=${busy}% iowait=${iow}% steal=${stl}% $(ctx) top:$(ps -eo pcpu,comm --sort=-pcpu | awk 'NR>1&&NR<5{printf " %s:%s", $2, $1}')"
      b=$a; bi=$ai; bw=$aw; br=$ar
    done;;
  *) echo "usage: util_perf_context.sh {stamp|run <cmd...>|watch [secs]}" >&2; exit 2;;
esac
