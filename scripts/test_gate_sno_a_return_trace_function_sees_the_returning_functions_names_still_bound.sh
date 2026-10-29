#!/usr/bin/env bash
# test_gate_sno_a_return_trace_function_sees_the_returning_functions_names_still_bound.sh -- a TRACE(F,'RETURN',,TRFN) function
# runs while F's result, formals and locals still hold F's values, as SPITBOL runs it; the caller's values come back afterwards.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25; aisnobol TEST's LTRACE output: after "<<< RETURN" SPITBOL prints ASSOCL's result, LTG, L
# and A, SCRIP printed "" for every one -- reduced over SPITCORE to LTRACE(2, .ASSOCL ~ NIL) and one ASSOCL call). The runtime
# epilogue rt_proc_epilogue_p read the result, restored the saved names (rt_name_restore) and THEN fired the RETURN trace
# (sno_trace_return and rt_trace_event), so a trace function reading $'ASSOCL' or $'L' read the caller's values. THE CURE: the
# restore point is computed first and the names are restored after both trace calls. NO MONITOR BRACKET: the SIR/TEST monitor run
# stopped at the controller's 99,999-event budget (the coo's f77940707 has since cured it); bracketed by reduction instead.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME; SCRIP under its --stlimit instrumentation switch, as the graders run it --
# a CALL trace function fires only under that switch, by the switch's design):
#   1-2  m3 / m4: a dynamic-scope function's RETURN trace reads its result, its formal and its local; the caller's X is back after
#   3    m3 and m4: the same for an FRETURN trace
#   4    CONTROL: the CALL trace reads the bound formal, as before
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_return_trace_function_sees_the_returning_functions_names_still_bound
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/ret.sno" <<'EOF'
        CODE('F K = "loc";  F = X X :(RETURN)')
        DEFINE('F(X)K', 'F')
        DEFINE('TRR()')                         :(TRR.END)
TRR     OUTPUT = 'ret F=[' F '] X=[' X '] K=[' K ']' :(RETURN)
TRR.END X = 'outer'
        K = 'outerk'
        TRACE('F', 'RETURN', , 'TRR')
        &TRACE = 100
        Y = F('ab')
        OUTPUT = 'after y=' Y ' x=' X ' k=' K
END
EOF
cat > "$T/fret.sno" <<'EOF'
        CODE('G K = "gl";  G = X :(FRETURN)')
        DEFINE('G(X)K', 'G')
        DEFINE('TRF()')                         :(TRF.END)
TRF     OUTPUT = 'fret X=[' X '] K=[' K '] type=' &RTNTYPE :(RETURN)
TRF.END X = 'outer'
        TRACE('G', 'RETURN', , 'TRF')
        &TRACE = 100
        G('zz')
        OUTPUT = 'after x=' X
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        DEFINE('F(X)K')                         :(F.END)
F       F = X X                                 :(RETURN)
F.END   DEFINE('TRC()')                         :(TRC.END)
TRC     OUTPUT = 'call X=[' X ']'               :(RETURN)
TRC.END X = 'outer'
        TRACE('F', 'CALL', , 'TRC')
        &TRACE = 100
        Y = F('ab')
END
EOF
for w in ret fret ctl; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ) || refuse "sbl did not run $w cleanly"; done
grep -qx 'ret F=\[abab\] X=\[ab\] K=\[loc\]' "$T/ret.oracle" || refuse "sbl's answer moved: [$(tr '\n' '|' < "$T/ret.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 10 "$SCRIP" --stlimit "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
rc=$(m3 ret); arm "m3: the RETURN trace reads the result, the formal and the local while bound" "$(same "$rc" ret.m3 ret.oracle)"
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 20 "$SCRIP" --stlimit --compile --out=r.s ret.sno < /dev/null > /dev/null 2>&1 && gcc r.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o r.bin > /dev/null 2>&1 && SCRIP_SNO_STMTKW=1 timeout -k 5 10 ./r.bin < /dev/null > ret.m4 2>&1; echo $? )
arm "m4: the RETURN trace reads the result, the formal and the local while bound" "$(same "$rc" ret.m4 ret.oracle)"
rc=$(m3 fret); arm "m3: an FRETURN trace reads the formal and the local while bound" "$(same "$rc" fret.m3 fret.oracle)"
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 20 "$SCRIP" --stlimit --compile --out=f.s fret.sno < /dev/null > /dev/null 2>&1 && gcc f.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o f.bin > /dev/null 2>&1 && SCRIP_SNO_STMTKW=1 timeout -k 5 10 ./f.bin < /dev/null > fret.m4 2>&1; echo $? )
arm "m4: an FRETURN trace reads the formal and the local while bound" "$(same "$rc" fret.m4 fret.oracle)"
rc=$(m3 ctl); arm "CONTROL: the CALL trace reads the bound formal" "$(same "$rc" ctl.m3 ctl.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
