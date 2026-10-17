#!/usr/bin/env bash
# test_gate_sno_a_define_call_on_a_default_build_never_enters_the_trace_layer.sh -- on a DEFAULT build (--stlimit off) a
# DEFINE'd function's call and return never enter the trace layer to learn it is idle: ZERO calls to trace_idle and to
# rt_trace_event_args over a witness of 400 calls (200 direct, 200 through APPLY); with the switch on and a trace budget
# armed, the same witness traces every port (cto 2026-09-26, row snobol4-a-define-call-on-a-default-build-still-enters-
# the-trace-layer-...; the ceo's CEO-1274 callgrind profile of indirect_dispatch: trace_idle 3.62 percent and
# rt_trace_event_args 2.92 percent of the kernel's instructions on a default build).
# THE INSTRUMENT is gdb's breakpoint hit count on the two functions (no perf here; callgrind is slower and mode-3 code
# lives in a slab it must be told about). Arms: (m3) scrip --run under gdb, (m4) the --compile'd and linked binary
# under gdb, both with the switch off: both counts 0; (control) --stlimit with SCRIP_TRACE=60: rt_trace_event_args is
# entered and the trace names the CALL and the RETURN of the function through the direct call and through APPLY.
# (2026-10-09, hq_snobol4: the layer body is rt_trace_event_args_ip since the trace hooks carry their island and the VALUE tap carries its pend; rt_trace_event_args and _i are one-line wrappers, so the counter sits on the body.)
# FAIL-ONCE: on 65bb1f417 (before the cure) arms m3 and m4 read trace_idle=400 rt_trace_event_args=400 each (one entry per call; the control arm read 2010 entries).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSED(2): cannot load lib_gate.sh"; exit 2; }; GATE_NAME=sno_a_define_call_on_a_default_build_never_enters_the_trace_layer
gate_require_fresh "$ROOT" src "$ROOT/scrip" || exit 2
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSED(2): no $ROOT/scrip -- run make"; exit 2; }
command -v gdb > /dev/null 2>&1 || { echo "⛔ REFUSED(2): no gdb -- the hit counter is absent"; exit 2; }
command -v gcc > /dev/null 2>&1 || { echo "⛔ REFUSED(2): no gcc -- the mode-4 arm cannot link"; exit 2; }
T="$(mktemp -d)" || { echo "⛔ REFUSED(2): mktemp failed"; exit 2; }; trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'SNO'
        DEFINE('add1(v)')                               :(add1_end)
add1    add1 = v + 1                                    :(RETURN)
add1_end fname = 'add1'
        sum = 0
        i = 1
direct  sum = sum + add1(i)
        i = LT(i, 200) i + 1                            :S(direct)
        i = 1
byname  sum = sum + APPLY(fname, i)
        i = LT(i, 200) i + 1                            :S(byname)
        OUTPUT = 'sum = ' sum
END
SNO
( cd "$T" && "$ROOT/scrip" --compile -o w4.s w.sno < /dev/null > cc4.out 2>&1 && gcc w4.s -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o w4.bin > ld4.out 2>&1 ) || { echo "⛔ REFUSED(2): the witness did not build in mode 4"; cat "$T/cc4.out" "$T/ld4.out" 2>/dev/null; exit 2; }
count() {   # count <label> <program...> : gdb hit counts of the two functions; prints "label idle=N args=N rc=R"
  local label="$1"; shift
  ( cd "$T" && timeout -k 5 120 gdb -batch -q -ex 'set breakpoint pending on' -ex 'set pagination off' -ex 'set confirm off' -ex 'break trace_idle' -ex 'ignore 1 1000000000' -ex 'break rt_trace_event_args_ip' -ex 'ignore 2 1000000000' -ex run -ex 'info breakpoints' --args "$@" > "$T/$label.gdb" 2>&1 < /dev/null ); local rc=$?
  grep -q '^sum = 40600$' "$T/$label.gdb" || { echo "$label REFUSED: the witness did not print sum = 40600 under gdb (rc=$rc)"; tail -5 "$T/$label.gdb"; return 2; }
  local idle args
  idle=$(awk '/^1 /{f=1} /^2 /{f=0} f && /already hit/ {for(i=1;i<=NF;i++) if ($i=="hit") print $(i+1)}' "$T/$label.gdb"); args=$(awk '/^2 /{f=1} f && /already hit/ {for(i=1;i<=NF;i++) if ($i=="hit") print $(i+1); exit}' "$T/$label.gdb")
  echo "$label idle=${idle:-0} args=${args:-0}"
}
red=0
for arm in m3 m4; do
  if [ "$arm" = m3 ]; then r=$(count m3 "$ROOT/scrip" --run "$T/w.sno"); else r=$(count m4 "$T/w4.bin"); fi
  case "$r" in *REFUSED*) echo "⛔ REFUSED(2): $r"; exit 2;; esac
  set -- $r; i="${2#idle=}"; a="${3#args=}"
  if [ "$i" = 0 ] && [ "$a" = 0 ]; then echo "ARM $arm ok: trace_idle=0 rt_trace_event_args=0 over 400 DEFINE calls on a default build"; else echo "ARM $arm RED: trace_idle=$i rt_trace_event_args=$a -- a DEFINE call on a default build still enters the trace layer to find it idle"; red=1; fi
done
r=$(SCRIP_TRACE=60 count ctl "$ROOT/scrip" --stlimit --run "$T/w.sno"); case "$r" in *REFUSED*) echo "⛔ REFUSED(2): control arm: $r"; exit 2;; esac
set -- $r; a="${3#args=}"
nd=$(grep -c '  add1(' "$T/ctl.gdb"); nr=$(grep -c '  RETURN add1 = ' "$T/ctl.gdb")
if [ "$a" -gt 0 ] && [ "$nd" -ge 2 ] && [ "$nr" -ge 2 ]; then echo "ARM ctl ok: with --stlimit and SCRIP_TRACE=60 the trace layer is entered (rt_trace_event_args=$a) and the trace names add1's CALL ($nd) and RETURN ($nr) through the direct call and through APPLY"; else echo "ARM ctl RED: rt_trace_event_args=$a add1 calls traced=$nd returns traced=$nr -- the switch no longer traces every port"; grep -m6 '\*\*\*\*' "$T/ctl.gdb"; red=1; fi
[ "$red" = 0 ] || { echo "RED: a DEFINE call on a default build must not enter the trace layer, and the switch must still trace every port"; exit 1; }
echo "PASS: a DEFINE call on a default build never enters the trace layer, and --stlimit still traces every port"
