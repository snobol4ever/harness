#!/usr/bin/env bash
# test_gate_monitor_a_binary_participant_ends_its_stream_when_the_trace_budget_is_spent.sh -- a binary monitor participant
# whose trace budget runs out goes quiet on the wire and ENDs its stream at exit; it never speaks the text protocol on the
# binary wire (cto 2026-09-26, row monitor-comm-var-falls-through-to-the-text-protocol-once-the-trace-budget-is-spent-...,
# measured by the coo 2026-09-25 21:2x and ruled at CEO-1274 (6)). THE DEFECT: comm_var in src/runtime/core/core.c returned
# early only while g_trace_budget was non-zero; at zero it fell through to the text mon_send VALUE, which g_monitor_bin did
# not guard, so the participant wrote nine text bytes onto the binary wire and blocked forever on an ack the reader could
# not send (it was waiting for the other four bytes of a 13-byte header) until the timeout killed it.
# THE WITNESS: a 20-iteration SNOBOL4 loop under SCRIP_TRACE=10 (ten events, then silence) with MONITOR_BIN=1 and an
# acking reader (../harness/scripts/monitor/read_one_wire.py, which stops on END). Two arms, one per mode:
#   the participant exits 0 within its timeout (124 is the wedge), its program ran to completion after the budget,
#   the reader saw exactly BUDGET traced records plus the exit LABEL, then ONE END record, last.
# FAIL-ONCE: on 6974ab821 (before the cure) both arms read RED -- rc=124, ten records, no END (the commit that lands
# this gate records that reading).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "REFUSED(2): cannot load lib_gate.sh"; exit 2; }; GATE_NAME=monitor_a_binary_participant_ends_its_stream_when_the_trace_budget_is_spent
gate_require_fresh "$ROOT" src "$ROOT/scrip" || exit 2   # a stale binary is a refusal, never a verdict
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSED(2): no $ROOT/scrip -- run make"; exit 2; }
READER="$HERE/monitor/read_one_wire.py"; [ -f "$READER" ] || { echo "⛔ REFUSED(2): no $READER -- nothing can ack the wire"; exit 2; }
command -v gcc > /dev/null 2>&1 || { echo "⛔ REFUSED(2): no gcc -- the mode-4 arm cannot link"; exit 2; }
T="$(mktemp -d)" || { echo "⛔ REFUSED(2): mktemp failed"; exit 2; }; trap 'rm -rf "$T"' EXIT
BUDGET=10
printf '        I = 0\nLOOP    I = I + 1\n        X = I * 2\n        LE(I, 20)   :S(LOOP)\n        OUTPUT = "done " I\nEND\n' > "$T/loop.sno"
( cd "$T" && "$ROOT/scrip" --trace --compile --monitor --out=loop4.s loop.sno < /dev/null > cc4.out 2>&1 && gcc loop4.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o loop4.bin > ld4.out 2>&1 ) || { echo "⛔ REFUSED(2): the witness did not build in mode 4"; cat "$T/cc4.out" "$T/ld4.out" 2>/dev/null; exit 2; }
red=0
arm() {   # arm <label> <command...> : runs the participant against a fresh acking reader and grades the wire
  local label="$1"; shift; local d="$T/$label"; mkdir -p "$d"
  ( timeout -k 5 20 python3 "$READER" "$d/r.fifo" "$d/g.fifo" > "$d/ctrl.log" 2>&1 ) & local ctrl=$!
  local k; for k in $(seq 1 30); do [ -p "$d/r.fifo" ] && [ -p "$d/g.fifo" ] && break; sleep 0.1; done
  ( cd "$d" && MONITOR_READY_PIPE="$d/r.fifo" MONITOR_GO_PIPE="$d/g.fifo" MONITOR_BIN=1 SCRIP_TRACE=$BUDGET timeout -k 5 8 "$@" > part.out 2> part.err < /dev/null ); local rc=$?
  wait "$ctrl" 2> /dev/null
  local n_rec n_end last_kind
  n_rec=$(grep -c '^\[ctrl\] #[0-9]* kind=' "$d/ctrl.log"); n_end=$(grep -c 'kind=END' "$d/ctrl.log"); last_kind=$(grep -o 'kind=[A-Z_]*' "$d/ctrl.log" | tail -1)
  local want=$((BUDGET + 2)) ok=1 why=""
  [ "$rc" = 0 ] || { ok=0; why="$why rc=$rc (124 is the participant wedged on an ack);"; }
  grep -q '^done 21$' "$d/part.out" || { ok=0; why="$why the program did not run to completion after the budget;"; }
  [ "$n_rec" = "$want" ] || { ok=0; why="$why records=$n_rec want=$want ($BUDGET traced + the exit LABEL + END);"; }
  [ "$n_end" = 1 ] && [ "$last_kind" = kind=END ] || { ok=0; why="$why END records=$n_end last=$last_kind (want one END, last);"; }
  if [ "$ok" = 1 ]; then echo "ARM $label ok: rc=0 records=$n_rec END last"; else echo "ARM $label RED:$why"; grep 'kind=\|EOF' "$d/ctrl.log" | tail -4; red=1; fi
}
arm m3 "$ROOT/scrip" --trace --run "$T/loop.sno"
arm m4 "$T/loop4.bin"
[ "$red" = 0 ] || { echo "RED: a binary participant that spends its trace budget must end its stream, never speak text on the binary wire"; exit 1; }
echo "PASS: a binary participant ends its stream when its trace budget is spent, in both modes"
