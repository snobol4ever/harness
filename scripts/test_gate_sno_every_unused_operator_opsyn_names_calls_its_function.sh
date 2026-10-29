#!/usr/bin/env bash
# test_gate_sno_every_unused_operator_opsyn_names_calls_its_function.sh -- every operator SPITBOL leaves undefined for OPSYN (manual
# ch. 8: unary ! % / # = |, binary & @ # % ~) calls the function OPSYN made it a synonym of, in both modes.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25; the IPC monitor bracket on aisnobol TEST.sno, step 82299, statement 551 "|("     " !AL)":
# spl "@551 CALL UNREAD", scr went to the error exit -- "error 29: undefined operator referenced"). SPITCORE makes unary ! a synonym
# of UNREAD with OPSYN('!', .UNREAD, 1). rt_call_arr_impl routes the OPSYN-able unary operators through the registered-function and
# APPLY path, but its list named / % # | and left ! and = out, so a unary ! fell through to the by-name table that knows only C
# builtins and raised error 29 for a program-defined synonym. THE CURE: the list is the manual's whole unary set (! and = join).
# Unary = does not parse as an operator yet ('X' ='a' reads as a second assignment -- a parser gap, named in the commit, not armed
# here); the runtime is ready for it when it does.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: unary ! % / # | and binary & @ # % ~ each call their OPSYN'd function
#   3    m3: unary ! inside a concatenation and as a function argument
#   4    CONTROL: a unary operator with no OPSYN still raises error 29, as SPITBOL does
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_every_unused_operator_opsyn_names_calls_its_function
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
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
        OUTPUT = 'excl ' !'a'
        OUTPUT = 'pct ' %'a'
        OUTPUT = 'slash ' /'a'
        OUTPUT = 'hash ' #'a'
        OUTPUT = 'bar ' |'a'
        OPSYN('&', .B, 2)
        OPSYN('@', .B, 2)
        OPSYN('#', .B, 2)
        OPSYN('%', .B, 2)
        OPSYN('~', .B, 2)
        OUTPUT = 'amp ' ('p' & 'q')
        OUTPUT = 'at ' ('p' @ 'q')
        OUTPUT = 'hash2 ' ('p' # 'q')
        OUTPUT = 'pct2 ' ('p' % 'q')
        OUTPUT = 'tilde2 ' ('p' ~ 'q')
END
EOF
cat > "$T/bang.sno" <<'EOF'
        DEFINE('U(X)')                          :(U.END)
U       U = '[' X ']'                           :(RETURN)
U.END   OPSYN('!', .U, 1)
        AL = 'list'
        OUTPUT = '     '   !AL
        OUTPUT = SIZE(!'abc') ' ' !!'n'
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        OUTPUT = 'before'
        OUTPUT = !'a'
        OUTPUT = 'after'
END
EOF
for w in ops bang ctl; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ); done
grep -qx 'excl u<a>' "$T/ops.oracle" && grep -qx 'tilde2 b<p,q>' "$T/ops.oracle" && grep -q 'ERROR 029' "$T/ctl.oracle" || refuse "sbl's answer moved: [$(cat "$T"/*.oracle | tr '\n' '|' | head -c 240)]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && timeout -k 5 10 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
rc=$(m3 ops); arm "m3: all ten reachable unused operators call their OPSYN'd function" "$(same "$rc" ops.m3 ops.oracle)"
rc=$( cd "$T" && timeout -k 5 20 "$SCRIP" --compile --out=o.s ops.sno < /dev/null > /dev/null 2>&1 && gcc o.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o o.bin > /dev/null 2>&1 && timeout -k 5 10 ./o.bin < /dev/null > ops.m4 2>&1; echo $? )
arm "m4: all ten reachable unused operators call their OPSYN'd function" "$(same "$rc" ops.m4 ops.oracle)"
rc=$(m3 bang); arm "m3: unary ! in a concatenation, an argument and nested" "$(same "$rc" bang.m3 bang.oracle)"
rc=$(m3 ctl); arm "CONTROL: unary ! with no OPSYN raises error 29 after 'before'" "$( { [ "$rc" != 0 ] && head -1 "$T/ctl.m3" | grep -qx before && grep -q 'error 29' "$T/ctl.m3" && ! grep -qx after "$T/ctl.m3"; } && echo ok || echo "rc=$rc [$(tr '\n' '|' < "$T/ctl.m3" | head -c 120)]")"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
