#!/usr/bin/env bash
# test_gate_sno_arg_names_only_a_functions_formals.sh -- ARG(F, I) names F's I-th formal argument and FAILS past the last formal,
# and LOCAL(F, I) names its locals, in both modes, as SPITBOL answers them.
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25; aisnobol TEST in mode 4 only, its last lines: SPITCORE's TDUMP listed PRINT.IN.FIELD's
# locals PIF...C. and PIF...V. under "Arguments" as well as under "Locals"). ARG answers from the DEFINE registry when it has the
# function and otherwise falls back to the runtime procedure record, whose nparams counts formals AND locals (the names the
# dynamic-scope prologue saves); LOCAL's fallback already subtracted rt_proc_nformals, ARG's used rt_proc_nparams. In mode 4 the
# library function is only in the runtime record, so ARG(.PRINT.IN.FIELD, 3) answered the first local. THE CURE: ARG's fallback
# counts rt_proc_nformals, as LOCAL's does. NO MONITOR BRACKET: a mode-4-only divergence of a dump TDUMP prints; found by
# diffing TEST's mode-4 stream against sbl -bf.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: ARG over a CODE-defined function with two formals and two locals, 1..3; LOCAL 1..3
#   3    m4: the same over a main-program DEFINE
#   4    CONTROL: ARG(F, 0) and LOCAL past the last local fail; ARG(F, 1) names the first formal
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_arg_names_only_a_functions_formals
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/code.sno" <<'EOF'
        CODE('PF PF = N S :(RETURN)')
        DEFINE('PF(N,S)C,V', 'PF')
        I = 0
A1      I = I + 1
        OUTPUT = 'arg ' I ' ' ARG(.PF, I)       :F(A2)
        LT(I, 3)                                :S(A1)
A2      I = 0
L1      I = I + 1
        OUTPUT = 'local ' I ' ' LOCAL(.PF, I)   :F(L2)
        LT(I, 3)                                :S(L1)
L2      OUTPUT = 'end'
END
EOF
cat > "$T/main.sno" <<'EOF'
        DEFINE('PM(N,S)C,V')                    :(PM.END)
PM      PM = N S                                :(RETURN)
PM.END  OUTPUT = 'arg2 ' ARG(.PM, 2)
        OUTPUT = (ARG(.PM, 3) 'arg3 SUCCEEDED', 'arg3 fails')
        OUTPUT = 'local1 ' LOCAL(.PM, 1)
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        DEFINE('PM(N,S)C,V')                    :(PM.END)
PM      PM = N S                                :(RETURN)
PM.END  OUTPUT = (ARG(.PM, 0) 'arg0 SUCCEEDED', 'arg0 fails')
        OUTPUT = (LOCAL(.PM, 3) 'local3 SUCCEEDED', 'local3 fails')
        OUTPUT = 'arg1 ' ARG(.PM, 1)
END
EOF
for w in code main ctl; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ) || refuse "sbl did not run $w cleanly"; done
grep -qx 'arg 2 S' "$T/code.oracle" && grep -qx 'arg3 fails' "$T/main.oracle" || refuse "sbl's answer moved: [$(cat "$T/code.oracle" "$T/main.oracle" | tr '\n' '|')]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && timeout -k 5 10 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
m4() { ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o "$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$1.bin" > /dev/null 2>&1 && timeout -k 5 10 "./$1.bin" < /dev/null > "$1.m4" 2>&1; echo $? ); }
rc=$(m3 code); arm "m3: ARG stops at the last formal; LOCAL names the locals (CODE-defined)" "$(same "$rc" code.m3 code.oracle)"
rc=$(m4 code); arm "m4: ARG stops at the last formal; LOCAL names the locals (CODE-defined)" "$(same "$rc" code.m4 code.oracle)"
rc=$(m4 main); arm "m4: ARG and LOCAL over a main-program DEFINE" "$(same "$rc" main.m4 main.oracle)"
rc=$(m3 ctl); arm "CONTROL: ARG(F,0) and LOCAL past the last local fail; ARG(F,1) is the first formal" "$(same "$rc" ctl.m3 ctl.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
