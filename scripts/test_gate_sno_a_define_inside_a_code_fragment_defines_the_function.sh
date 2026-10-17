#!/usr/bin/env bash
# test_gate_sno_a_define_inside_a_code_fragment_defines_the_function.sh -- a DEFINE statement inside a CODE() fragment defines its
# function at run time, with its entry label in that fragment, including a function that re-DEFINEs itself onto a new entry label
# (SPITCORE's LTRACE: "DEFINE('LTRACE(PARAM,L)F,TFNAME','LTRACE0')" inside the lazily loaded LTRACE body).
#
# ⛔ THE DEFECT (hq_snobol4 2026-09-25; aisnobol TEST, output line 496 under the graders' switch: SCRIP stopped with "FATAL
# lower_snobol4 (GZ#5 subset): DEFINE inside a runtime-compiled CODE/EVAL fragment is outside the landed subset" when LOADEX
# compiled LTRACE from the library). NO MONITOR BRACKET: a compile-time refusal, no event. The fragment lowerer refused every DEFINE
# (sno_fragment_reject_define), and past that the TT_FNC DEFINE arm refused a literal prototype the main program had not hoisted.
# The runtime already defines a function whose entry label lies in a fragment -- DEXTERN runs DEFINE(PROTO, LBL) against a CODE
# label, and rt_call_proc_descr resolves the entry at call time. THE CURE: a fragment clears the hoisted-DEFINE registry, as it did,
# and a literal DEFINE in a fragment lowers as the ordinary runtime DEFINE call. TEST then runs to its end (823 lines, rc 0).
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: a fragment DEFINEs H with its entry label HL in the same fragment; a function re-DEFINEs itself onto a new entry
#   3    m3: a fragment-defined function with a local keeps its caller's variable of the same name
#   4    m3: a DEFINE of a system function inside a fragment raises error 248, as SPITBOL does (the refusal no longer pre-empts it)
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_define_inside_a_code_fragment_defines_the_function
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cat > "$T/frag.sno" <<'EOF'
        CODE('LD DEFINE("H(X)", "HL") :(RETURN);HL H = X X :(RETURN)')
        DEFINE('LD()')
        LD()
        OUTPUT = 'h ' H('ab')
        CODE('RD DEFINE("RD(Y)", "RD0");RD0 RD = "new " Y :(RETURN)')
        DEFINE('RD(Y)', 'RD')
        OUTPUT = 'first ' RD('a')
        OUTPUT = 'second ' RD('b')
END
EOF
cat > "$T/local.sno" <<'EOF'
        CODE('MK DEFINE("SQ(N)T") :(RETURN);SQ T = N * N;  SQ = T :(RETURN)')
        DEFINE('MK()')
        MK()
        T = 'outer'
        OUTPUT = 'sq ' SQ(7) ' ' T
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        CODE('MK DEFINE("LT(PARAM,L)F", "LT0") :(RETURN);LT0 LT = PARAM :(RETURN)')
        DEFINE('MK()')
        OUTPUT = 'before'
        MK()
        OUTPUT = 'after'
END
EOF
for w in frag local ctl; do ( cd "$T" && timeout -k 5 10 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ); done
grep -qx 'h abab' "$T/frag.oracle" && grep -qx 'second new b' "$T/frag.oracle" && grep -q 'ERROR 248' "$T/ctl.oracle" || refuse "sbl's answer moved: [$(cat "$T"/*.oracle | tr '\n' '|' | head -c 240)]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1 [$(tr '\n' '|' < "$T/$2" | head -c 110)]"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && timeout -k 5 10 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
rc=$(m3 frag); arm "m3: a fragment DEFINEs H at HL; a function re-DEFINEs itself onto a new entry" "$(same "$rc" frag.m3 frag.oracle)"
rc=$( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o f.s frag.sno < /dev/null > /dev/null 2>&1 && gcc f.s -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o f.bin > /dev/null 2>&1 && timeout -k 5 10 ./f.bin < /dev/null > frag.m4 2>&1; echo $? )
arm "m4: a fragment DEFINEs H at HL; a function re-DEFINEs itself onto a new entry" "$(same "$rc" frag.m4 frag.oracle)"
rc=$(m3 local); arm "m3: a fragment-defined function's local leaves the caller's variable alone" "$(same "$rc" local.m3 local.oracle)"
rc=$(m3 ctl); arm "m3: DEFINE of a system function in a fragment raises error 248 after 'before'" "$( { [ "$rc" != 0 ] && head -1 "$T/ctl.m3" | grep -qx before && grep -q 'error 248' "$T/ctl.m3" && ! grep -qx after "$T/ctl.m3"; } && echo ok || echo "rc=$rc [$(tr '\n' '|' < "$T/ctl.m3" | head -c 140)]")"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
