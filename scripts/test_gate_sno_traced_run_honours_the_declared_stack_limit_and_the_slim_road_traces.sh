#!/usr/bin/env bash
# test_gate_sno_traced_run_honours_the_declared_stack_limit_and_the_slim_road_traces.sh -- a program near its declared stack limit
# behaves the same traced and untraced, because --trace no longer switches every SNOBOL4 call onto the non-slim C road.
#
# THE DEFECT (row runtime-the-traced-run-honours-the-same-declared-stack-limit-as-the-untraced-run-..., the coo's finding
# 2026-10-03, ceo CEO-1501/1502): bb_scc_probe turned the slim (direct) call road off whenever g_trace_budget was set, because
# only the non-slim road (rt_proc_call_open, rt.c) fired sno_trace_call / sno_trace_return under the trace budget -- the slim
# road's DEFINE prologue and RETURN hooks were gated on &TRACE and &FTRACE alone. So a traced SNOBOL4 program was a different
# program: DEFINE('R(N)') recursing 30000 deep at -s4096k was ERROR 246 untraced and depth=30000 under --trace (the untraced
# ceiling 29000..29500, the traced one above 33000), every program near its stack limit read NOT MONITOR-SAFE, and the monitor
# bracket could not reach a stack-depth defect. The cure: bb_define.cpp fires sno_trace_call at entry and sno_trace_return at
# RETURN when g_trace_budget != 0 (the same emitters the non-slim road uses, monitor and trace stream only, never stdout), and
# bb_scc_probe keeps the slim road under trace; SCRIP_SCC_OFF=1 stays the control arm (no slim calls at all).
#
# THE ARMS:
#   1  untraced at -s4096k: depth 29000 answers, depth 29500 is ERROR 246                 -- the premise; REFUSE if the ceiling moved
#   2  traced at -s4096k: depth 29000 answers, depth 29500 is ERROR 246, no depth=29500    -- RED on base (depth=29500 printed)
#   3  the --trace event stream of a call witness is identical on the slim road and under SCRIP_SCC_OFF=1 (non-slim)   -- RED on base (no CALL/RETURN events)
#   4  monitor_run.sh --oracle on that witness reads AGREE (REFUSE if the SPITBOL participant is absent)                 -- RED on base (DIVERGE at step 3)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no tmpdir, the premise moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=sno_traced_run_honours_the_declared_stack_limit_and_the_slim_road_traces
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
T=$(mktemp -d) || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cd "$T" || refuse "cannot enter $T"
mk() { printf "        DEFINE('R(N)')                    :(e)\nR       R = EQ(N,0) 0                      :S(RETURN)\n        R = R(N - 1) + 1                   :(RETURN)\ne       OUTPUT = 'depth=' R(%s)\nEND\n" "$1" > "r$1.sno"; }
mk 29000; mk 29500
verdict() { grep -v -E '^\s*(stmt|call|ret|assign|TRACE|\[|\*\*\*\*)' | tail -1 | grep -o -E 'depth=[0-9]+|ERROR 246' | head -1; }
RC=0
u1=$(timeout -k 5 60 "$SCRIP" -s4096k r29000.sno < /dev/null 2>&1 | verdict); u2=$(timeout -k 5 60 "$SCRIP" -s4096k r29500.sno < /dev/null 2>&1 | verdict)
if [ "$u1" = "depth=29000" ] && [ "$u2" = "ERROR 246" ]; then echo "  arm 1 PASS (untraced: 29000 answers, 29500 is ERROR 246 at -s4096k)"; else refuse "the untraced ceiling moved: 29000 [$u1] 29500 [$u2] -- re-cut the depths"; fi
t1=$(timeout -k 5 180 "$SCRIP" --trace -s4096k r29000.sno < /dev/null 2>&1 | verdict); t2=$(timeout -k 5 180 "$SCRIP" --trace -s4096k r29500.sno < /dev/null 2>&1 | verdict)
if [ "$t1" = "depth=29000" ] && [ "$t2" = "ERROR 246" ]; then echo "  arm 2 PASS (traced: the same ceiling, 29000 answers, 29500 is ERROR 246)"; else echo "  arm 2 FAIL (traced: 29000 [$t1] 29500 [$t2] -- the traced run has a different stack footprint)"; RC=1; fi
printf "        DEFINE('R(N)')                    :(e)\nR       R = EQ(N,0) 0                      :S(RETURN)\n        R = R(N - 1) + 1                   :(RETURN)\ne       OUTPUT = 'depth=' R(50)\n        OUTPUT = 'twice=' R(3) R(4)\nEND\n" > m.sno
timeout -k 5 60 "$SCRIP" --trace m.sno < /dev/null 2>&1 | grep -v -E '^(depth|twice)=' > slim.tr
SCRIP_SCC_OFF=1 timeout -k 5 60 "$SCRIP" --trace m.sno < /dev/null 2>&1 | grep -v -E '^(depth|twice)=' > nonslim.tr
if [ -s slim.tr ] && cmp -s slim.tr nonslim.tr; then echo "  arm 3 PASS (the slim and the non-slim road emit the same $(wc -l < slim.tr) trace events)"; else echo "  arm 3 FAIL (trace streams differ: slim $(wc -l < slim.tr) lines, non-slim $(wc -l < nonslim.tr); first difference: $(diff slim.tr nonslim.tr | head -2 | tr '\n' ' ' | cut -c1-120))"; RC=1; fi
if [ -x /home/resources/x64/bin/sbl ] && [ -f "$HERE/monitor_run.sh" ]; then
  timeout -k 5 600 bash "$HERE/monitor_run.sh" m.sno --oracle > mo.txt 2>&1; mrc=$?
  if [ $mrc -eq 0 ] && grep -q 'AGREE' mo.txt; then echo "  arm 4 PASS (monitor_run --oracle AGREE: $(grep -o -E 'AGREE=[0-9]+ DIVERGE=[0-9]+' mo.txt | head -1))"; elif [ $mrc -eq 2 ]; then refuse "monitor_run.sh refused: $(grep -m1 -E 'REFUSE' mo.txt | cut -c1-120)"; else echo "  arm 4 FAIL (monitor_run --oracle rc $mrc: $(grep -m1 -E 'DIVERGE|VERDICT' mo.txt | cut -c1-120))"; RC=1; fi
else refuse "no SPITBOL oracle or no monitor_run.sh -- arm 4 cannot measure"; fi
if [ $RC -eq 0 ]; then echo "GATE PASS(0) [$NAME]: the traced run overflows where the untraced run does, the slim road traces every call and return, the oracle monitor agrees"; else echo "GATE FAIL(1) [$NAME]"; fi
exit $RC
