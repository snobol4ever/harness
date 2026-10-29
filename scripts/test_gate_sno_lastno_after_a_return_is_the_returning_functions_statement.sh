#!/usr/bin/env bash
# test_gate_sno_lastno_after_a_return_is_the_returning_functions_statement.sh -- when a program-defined function returns, &LASTNO
# and &LASTLINE become the statement and line the function returned from and &STNO / &LINE the caller's again, as SPITBOL answers
# them -- read in the same statement, after RETURN and FRETURN, and whether the function was called directly, through an OPSYN
# operator or through APPLY.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25; aisnobol TEST's LTRACE output under the graders' switch: sbl ">>> 943 ==> 944 ==>" and
# "<<< RETURN <== 952 <== 951", SCRIP "17" in both &LASTNO places -- 17 is the last statement of SPITCORE's PRT.VIA.OUTPUT, which
# LTRACE1 reaches through the unary | operator). Measured against sbl -bf: after B = G() &LASTNO, SPITBOL answers G's last statement
# (3) and SCRIP the one before it (2); after an FRETURN SCRIP answered the caller's own statement. THE CLASS -- every way back from
# a function: bb_define's two &STNO restores (the BB RETURN/FRETURN floaters) put the caller's &STNO/&LINE back but never moved the
# callee's into &LASTNO/&LASTLINE, and the C-entered calls (APPLY_fn -- the OPSYN-operator and APPLY() paths -- and APPLY()'s fast
# open, rt_apply_open / rt_apply_land) did not restore &STNO at all. THE CURE: each return path first makes the callee's statement
# and line the previous ones, then restores the caller's (bb_stno_last_from_callee; APPLY_fn's wrapper; rt_lvl_stno_stash /
# rt_lvl_stno_land over the level record the BB prologue already uses).
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME, SCRIP under its --stlimit statement instrumentation, as the graders run):
#   1-2  m3 / m4: &LASTNO / &STNO / &LASTLINE / &LINE read in the calling statement after a RETURN, and after an FRETURN
#   3    m3: after a call through an OPSYN operator, through APPLY(), and a direct call, the next statement's &LASTNO
#   4    m3: inside a TRACE function, &LASTNO / &STNO around calls the trace function makes
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_lastno_after_a_return_is_the_returning_functions_statement
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/ret.sno" <<'EOF'
        DEFINE('G()')                           :(G.END)
G       X = 1
        Y = 2                                   :(RETURN)
G.END   DEFINE('H()')                           :(H.END)
H       X = 1                                   :(FRETURN)
H.END   A = 1
        B = G() &LASTNO '/' &STNO '/' &LASTLINE '/' &LINE
        OUTPUT = 'ret ' B
        C = (H(), &LASTNO '/' &STNO)
        OUTPUT = 'fret ' C
END
EOF
cat > "$T/paths.sno" <<'EOF'
        DEFINE('P(X)')                          :(P.END)
P       X = 1
        P = 2                                   :(RETURN)
P.END   DEFINE('Q(X)')                          :(Q.END)
Q       Q = 3                                   :(RETURN)
Q.END   OPSYN('|', .Q, 1)
        OPSYN('#', .P, 1)
        A = 1
        #'z'
        OUTPUT = 'after-op ' &LASTNO
        APPLY(.P, 'z')
        OUTPUT = 'after-apply ' &LASTNO
        P('z')
        OUTPUT = 'after-call ' &LASTNO
        B = |'z' &LASTNO
        OUTPUT = 'same-stmt-op ' B
END
EOF
cat > "$T/trace.sno" <<'EOF'
        DEFINE('G()')                           :(G.END)
G       X = 1
        Y = 2                                   :(RETURN)
G.END   DEFINE('F(A)')                          :(F.END)
F       F = A                                   :(RETURN)
F.END   DEFINE('TRC()')                         :(TRC.END)
TRC     OUTPUT = 'tr1 ' &LASTNO '/' &STNO
        G()
        OUTPUT = 'tr2 ' &LASTNO '/' &STNO
        Z = G() &LASTNO '/' &STNO
        OUTPUT = 'tr3 ' Z                       :(RETURN)
TRC.END TRACE('F', 'CALL', , 'TRC')
        &TRACE = 100
        Q = 1
        R = F(5)
        OUTPUT = 'after ' &LASTNO '/' &STNO
END
EOF
for w in ret paths trace; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ) || refuse "sbl did not run $w cleanly"; done
grep -qE '^ret [0-9]+/[0-9]+/[0-9]+/[0-9]+$' "$T/ret.oracle" && grep -qE '^fret [0-9]+/[0-9]+$' "$T/ret.oracle" || refuse "sbl's answer moved: [$(tr '\n' '|' < "$T/ret.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 10 "$SCRIP" --stlimit "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
rc=$(m3 ret); arm "m3: the statement keywords in the calling statement after RETURN and FRETURN" "$(same "$rc" ret.m3 ret.oracle)"
rc=$( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 20 "$SCRIP" --stlimit --compile --out=r.s ret.sno < /dev/null > /dev/null 2>&1 && gcc r.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o r.bin > /dev/null 2>&1 && SCRIP_SNO_STMTKW=1 timeout -k 5 10 ./r.bin < /dev/null > ret.m4 2>&1; echo $? )
arm "m4: the statement keywords in the calling statement after RETURN and FRETURN" "$(same "$rc" ret.m4 ret.oracle)"
rc=$(m3 paths); arm "m3: &LASTNO after an OPSYN operator call, an APPLY() and a direct call" "$(same "$rc" paths.m3 paths.oracle)"
rc=$(m3 trace); arm "m3: &LASTNO / &STNO inside a TRACE function around the calls it makes" "$(same "$rc" trace.m3 trace.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
