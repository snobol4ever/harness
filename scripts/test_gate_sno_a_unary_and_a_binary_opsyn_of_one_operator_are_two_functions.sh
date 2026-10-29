#!/usr/bin/env bash
# test_gate_sno_a_unary_and_a_binary_opsyn_of_one_operator_are_two_functions.sh -- OPSYN('%', .B, 2) and OPSYN('%', .U, 1) make
# binary % call B and unary % call U, whichever came last, as SPITBOL keeps a unary and a binary slot per operator symbol.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25; aisnobol TEST's next divergence after the unary-! landing, output line 188 "Centered.":
# SCRIP printed "Argument number 1 to FAIL.IF.NIL.ELSE.SUCCEED (X) has illegal datatype INTEGER"). SPITCORE makes binary % a
# synonym of PRINT.IN.FIELD (OPSYN('%', .PRINT.IN.FIELD, 2), line 328) and later unary % a synonym of FAIL.IF.NIL.ELSE.SUCCEED
# (line 356). opsyn() registered both under the bare symbol, so the second overwrote the first and "12 % ' '" called the unary
# function with the binary operator's left operand. THE CURE: a unary OPSYN registers under the operator's unary key
# (sn4_unary_op_key: "unary%" -- not a spelling any SNOBOL4 identifier can take), and the unary call paths (rt_call_arr_impl's
# OPSYN-able unary list and the by-name ! arm) look that key up; the binary operators keep the bare symbol.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: binary-then-unary % and unary-then-binary # each call their own function
#   3    m3: all ten reachable unused operators still call their OPSYN'd function (the unary-key rename leaves them whole)
#   4    m3: an operator with only a binary OPSYN still raises error 29 when used unary (it no longer calls the binary function)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_unary_and_a_binary_opsyn_of_one_operator_are_two_functions
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/two.sno" <<'EOF'
        DEFINE('U(X)')                          :(U.END)
U       U = 'u<' X '>'                          :(RETURN)
U.END   DEFINE('B(X,Y)')                        :(B.END)
B       B = 'b<' X ',' Y '>'                    :(RETURN)
B.END   OPSYN('%', .B, 2)
        OPSYN('%', .U, 1)
        OUTPUT = 'bin ' (3 % 'q')
        OUTPUT = 'un ' %'r'
        OPSYN('#', .U, 1)
        OPSYN('#', .B, 2)
        OUTPUT = 'bin2 ' ('s' # 't')
        OUTPUT = 'un2 ' #'v'
END
EOF
cat > "$T/ops.sno" <<'EOF'
        DEFINE('U(X)')                          :(U.END)
U       U = 'u<' X '>'                          :(RETURN)
U.END   DEFINE('B(X,Y)')                        :(B.END)
B       B = 'b<' X ',' Y '>'                    :(RETURN)
B.END   OPSYN('!', .U, 1)
        OPSYN('%', .U, 1)
        OPSYN('/', .U, 1)
        OPSYN('#', .U, 1)
        OPSYN('|', .U, 1)
        OPSYN('&', .B, 2)
        OPSYN('@', .B, 2)
        OPSYN('#', .B, 2)
        OPSYN('%', .B, 2)
        OPSYN('~', .B, 2)
        OUTPUT = !'a' %'a' /'a' #'a' |'a'
        OUTPUT = ('p' & 'q') ('p' @ 'q') ('p' # 'q') ('p' % 'q') ('p' ~ 'q')
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        DEFINE('B(X,Y)')                        :(B.END)
B       B = 'b<' X ',' Y '>'                    :(RETURN)
B.END   OPSYN('~', .B, 2)
        OPSYN('#', .B, 2)
        OUTPUT = 'before'
        OUTPUT = #'a'
        OUTPUT = 'after'
END
EOF
for w in two ops ctl; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ); done
grep -qx 'bin b<3,q>' "$T/two.oracle" && grep -qx 'un2 u<v>' "$T/two.oracle" && grep -q 'ERROR 029' "$T/ctl.oracle" || refuse "sbl's answer moved: [$(cat "$T"/*.oracle | tr '\n' '|' | head -c 240)]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && timeout -k 5 10 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
rc=$(m3 two); arm "m3: a unary and a binary OPSYN of one symbol call their own functions" "$(same "$rc" two.m3 two.oracle)"
rc=$( cd "$T" && timeout -k 5 20 "$SCRIP" --compile --out=t.s two.sno < /dev/null > /dev/null 2>&1 && gcc t.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o t.bin > /dev/null 2>&1 && timeout -k 5 10 ./t.bin < /dev/null > two.m4 2>&1; echo $? )
arm "m4: a unary and a binary OPSYN of one symbol call their own functions" "$(same "$rc" two.m4 two.oracle)"
rc=$(m3 ops); arm "m3: the ten reachable unused operators, unary and binary together" "$(same "$rc" ops.m3 ops.oracle)"
rc=$(m3 ctl); arm "m3: a binary-only OPSYN used unary raises error 29 after 'before'" "$( { [ "$rc" != 0 ] && head -1 "$T/ctl.m3" | grep -qx before && grep -q 'error 29' "$T/ctl.m3" && ! grep -qx after "$T/ctl.m3"; } && echo ok || echo "rc=$rc [$(tr '\n' '|' < "$T/ctl.m3" | head -c 120)]")"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
