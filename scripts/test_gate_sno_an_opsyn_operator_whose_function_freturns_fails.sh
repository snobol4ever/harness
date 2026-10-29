#!/usr/bin/env bash
# test_gate_sno_an_opsyn_operator_whose_function_freturns_fails.sh -- an operator made a synonym of a program-defined function by
# OPSYN (unary % / #, binary # ~ &) FAILS when that function returns through FRETURN, as a call of the function by its own name does.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25, walking aisnobol SIR under the TENET crawl; the monitor refused SIR as NOT MONITOR-SAFE past
# its error cascade, so the bracket was taken by instrumenting SIR's MATCH1: SPITBOL "MEMQ('IS', VARS)" fails, SCRIP succeeds).
# SPITCORE's MEMQ is (LISTARG(.MEMQ,2,.L) %MEMBER(A,L)) :S(RETURN)F(FRETURN) with unary % OPSYN'd to FAIL.IF.NIL.ELSE.SUCCEED, which
# FRETURNs on NIL. An operator call reaches APPLY_fn and the driver's user-call hook, which called the function through
# rt_call_named_proc and read its FAIL as "could not call": it retried by the entry label, then fell to call_user_function, the
# AST fallback, which answered the null string -- so every failing operator call SUCCEEDED with ''. THE CURE: the hook calls the
# procedure once when the name resolves to one that runs (rt_proc_named_runs: a registered procedure with a body or a dynamic entry)
# and returns what it returned, FAIL included; the fallback runs only when no procedure answers the name.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: unary % on FRETURN fails alone, inside a concatenation and inside a function body; % on RETURN succeeds
#   3    m3: binary # ~ & on FRETURN fail, and succeed on RETURN
#   4    m3: the function body runs exactly once per failing operator call
#   5    CONTROL: a name synonym OPSYN('G','F2') on FRETURN fails, as before
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_an_opsyn_operator_whose_function_freturns_fails
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/un.sno" <<'EOF'
        DEFINE('FN(X)')                         :(FN.END)
FN      IDENT(X, 'bad')                         :S(FRETURN)
        FN = X                                  :(RETURN)
FN.END  OPSYN('%', .FN, 1)
        %'ok'                                   :F(A1)
        OUTPUT = 'ok succeeded'
A1      %'bad'                                  :S(A2)
        OUTPUT = 'bad failed'                   :(A3)
A2      OUTPUT = 'bad SUCCEEDED'
A3      X = (%'bad' 'z')                        :F(A4)
        OUTPUT = 'concat SUCCEEDED'             :(A5)
A4      OUTPUT = 'concat failed'
A5      DEFINE('MQ(A)')                         :(MQ.END)
MQ      (DIFFER(A) %A)                          :S(RETURN)F(FRETURN)
MQ.END  MQ('bad')                               :S(A6)
        OUTPUT = 'MQ failed'                    :(END)
A6      OUTPUT = 'MQ SUCCEEDED'
END
EOF
cat > "$T/bin.sno" <<'EOF'
        DEFINE('F2(X,Y)')                       :(F2.END)
F2      IDENT(X, 'bad')                         :S(FRETURN)
        F2 = X Y                                :(RETURN)
F2.END  OPSYN('#', .F2, 2)
        OPSYN('~', .F2, 2)
        OPSYN('&', .F2, 2)
        ('bad' # 'z')                           :S(B1)
        OUTPUT = 'hash failed'                  :(B2)
B1      OUTPUT = 'hash SUCCEEDED'
B2      ('bad' ~ 'z')                           :S(B3)
        OUTPUT = 'tilde failed'                 :(B4)
B3      OUTPUT = 'tilde SUCCEEDED'
B4      ('bad' & 'z')                           :S(B5)
        OUTPUT = 'amp failed'                   :(B6)
B5      OUTPUT = 'amp SUCCEEDED'
B6      OUTPUT = 'ok ' ('a' # 'b') ('c' ~ 'd') ('e' & 'f')
END
EOF
cat > "$T/cnt.sno" <<'EOF'
        DEFINE('FN(X)')                         :(FN.END)
FN      N = N + 1
        IDENT(X, 'bad')                         :S(FRETURN)
        FN = X                                  :(RETURN)
FN.END  OPSYN('#', .FN, 1)
        N = 0
        #'bad'
        OUTPUT = 'runs after one failing #: ' N
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        DEFINE('F2(X,Y)')                       :(F2.END)
F2      IDENT(X, 'bad')                         :S(FRETURN)
        F2 = X Y                                :(RETURN)
F2.END  OPSYN('G', 'F2')
        G('bad', 'q')                           :S(C1)
        OUTPUT = 'G failed'                     :(END)
C1      OUTPUT = 'G SUCCEEDED'
END
EOF
for w in un bin cnt ctl; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ) || refuse "sbl did not run $w cleanly"; done
grep -qx 'bad failed' "$T/un.oracle" && grep -qx 'amp failed' "$T/bin.oracle" && grep -q ': 1$' "$T/cnt.oracle" || refuse "sbl's answer moved: [$(cat "$T"/*.oracle | tr '\n' '|' | head -c 200)]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && timeout -k 5 10 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
rc=$(m3 un); arm "m3: unary % on FRETURN fails (alone, in a concatenation, in a function)" "$(same "$rc" un.m3 un.oracle)"
rc=$( cd "$T" && timeout -k 5 20 "$SCRIP" --compile --out=u.s un.sno < /dev/null > /dev/null 2>&1 && gcc u.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o u.bin > /dev/null 2>&1 && timeout -k 5 10 ./u.bin < /dev/null > un.m4 2>&1; echo $? )
arm "m4: unary % on FRETURN fails (alone, in a concatenation, in a function)" "$(same "$rc" un.m4 un.oracle)"
rc=$(m3 bin); arm "m3: binary # ~ & on FRETURN fail, on RETURN succeed" "$(same "$rc" bin.m3 bin.oracle)"
rc=$(m3 cnt); arm "m3: the function body runs once per failing operator call" "$(same "$rc" cnt.m3 cnt.oracle)"
rc=$(m3 ctl); arm "CONTROL: a name synonym on FRETURN fails" "$(same "$rc" ctl.m3 ctl.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
