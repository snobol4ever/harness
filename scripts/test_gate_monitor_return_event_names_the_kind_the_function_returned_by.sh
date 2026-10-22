#!/usr/bin/env bash
# test_gate_monitor_return_event_names_the_kind_the_function_returned_by.sh -- under the IPC sync-step monitor, SCRIP's RETURN event
# carries the kind the function actually returned by -- RETURN, FRETURN or NRETURN -- as the SPITBOL fork's does, so a bracket over
# a program that calls an NRETURN function no longer stops at its first NRETURN.
#
# ⛔ THE DEFECT (row snobol4-monitor-the-scrip-return-event-reports-return-for-an-nreturn-function-..., found by the cfo, CFO-166):
# sno_trace_return (src/runtime/core/core.c) spelled the wire kind from the returned VALUE alone -- FRETURN when it failed, else
# RETURN -- so an NRETURN never reached the wire, and every bracket over a bootstrap parser (nPush, Shift, Reduce all NRETURN) read
# DIVERGE at its first one: spl @2 RETURN F (NRETURN), scr @2 RETURN F (RETURN). The program itself was right (&RTNTYPE NRETURN).
# The cfo's reading that g_kw_rtntype was stale when the event was sent is REFUTED by gdb: at sno_trace_return, reached from
# rt_proc_epilogue_p after the body's IR_DEFINE return floater ran rt_kw_set_rtntype_role, g_kw_rtntype already reads NRETURN.
# THE CURE: sno_trace_return sends FRETURN for a failed return, NRETURN when g_kw_rtntype says the function returned by name, else RETURN.
#
# THE ARMS:
#   1  monitor_run.sh --oracle on the row's nine-line witness (an NRETURN and a RETURN function) reads AGREE, DIVERGE=0 -- RED on base
#   2  monitor_run.sh --oracle on RETURN, NRETURN and FRETURN functions called in turn, each twice (the kind switching back and
#      forth), reads AGREE, DIVERGE=0                                                                         -- RED on base
#   3  CONTROL: the witness's own output under m3 equals sbl -bf (v NRETURN) -- the program was never the defect
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the monitor could not measure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=monitor_return_event_names_the_kind_the_function_returned_by
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -x "$HERE/monitor_run.sh" ] || refuse "no monitor_run.sh"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
printf '%s\n' "        DEFINE('F()')                   :(F_end)" "F       F = .DUMMY                       :(NRETURN)" "F_end   DEFINE('G()')                   :(G_end)" \
    "G       G = 'v'                          :(RETURN)" "G_end   X = G()" "        Y = F()" "        OUTPUT = X ' ' &RTNTYPE" "END" > "$T/nret.sno"
cat > "$T/kinds.sno" <<'EOF'
        DEFINE('byvalue()')                     :(byvalue_end)
byvalue byvalue = 'v'                           :(RETURN)
byvalue_end
        DEFINE('byname()')                      :(byname_end)
byname  byname = .held                          :(NRETURN)
byname_end
        DEFINE('failing()')                     :(failing_end)
failing                                         :(FRETURN)
failing_end
        held = 'h'
        first = byvalue()
        second = byname()
        failing()                               :S(odd)
        third = byvalue()
        fourth = byname()
        failing()                               :S(odd)
        OUTPUT = first second third fourth ' ' &RTNTYPE :(END)
odd     OUTPUT = 'failing succeeded'
END
EOF
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
mon() { ( cd "$T" && timeout -k 5 300 bash "$HERE/monitor_run.sh" "$1.sno" --oracle > "$1.mon" 2>&1 ); local r=$?
    [ "$r" = 2 ] && refuse "the monitor could not measure $1: $(grep -m1 -E 'REFUSE|DIVERGE' "$T/$1.mon" | cut -c1-160)"
    local v; v=$(grep -o 'AGREE=[0-9]* DIVERGE=[0-9]* UNGRADED=[0-9]*' "$T/$1.mon" | tail -1)
    [ "$r" = 0 ] && printf '%s' "$v" | grep -q 'DIVERGE=0 ' && echo ok || echo "rc=$r [$v] $(grep -m1 '^| \*\*>' "$T/$1.mon" | cut -c1-140)"; }
arm "monitor --oracle: an NRETURN and a RETURN function, the row's witness" "$(mon nret)"
arm "monitor --oracle: RETURN, NRETURN and FRETURN functions, each called twice" "$(mon kinds)"
want=$(cd "$T" && timeout -k 5 20 "$SBL" -bf nret.sno < /dev/null 2>&1); got=$(cd "$T" && timeout -k 5 20 "$SCRIP" nret.sno < /dev/null 2>&1)
[ "$want" = "v NRETURN" ] || refuse "sbl's answer moved: [$want]"
arm "CONTROL m3: the witness prints what sbl prints" "$([ "$got" = "$want" ] && echo ok || echo "got [$got] want [$want]")"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
