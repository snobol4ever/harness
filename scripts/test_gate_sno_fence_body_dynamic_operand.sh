#!/bin/bash
# SNOBOL4: a dynamic (variable) operand consumed INSIDE A FENCE BODY must earn a frame slot, exactly as one
# inside an ARBNO body does. FENCE(LEN(N) "-") "Q" against "ab-Q" MATCHES in SPITBOL; SCRIP printed NOMATCH
# in BOTH modes because xop_frame_member's gamma walk cannot reach a consumer inside a FENCE body -- IR_t
# carries only gamma and omega, so a body reachable only through a backtracking edge is never walked, and the
# allocator returned "not found" in the same spelling it uses for "not there". Cure: choice_body_member
# (src/emitter/emit.cpp) grants the slot when the consumer is POSITIVELY LOCATED inside an ARBNO *or* a
# FENCE0/FENCE1 extent -- a hazard proven, not guessed. Row snobol4-csnobol4-nqueens-sigsegv, FENCE half.
#
# ⛔⭐ WHY THIS GATE EXISTS AT ALL, and it is the reason the cure was nearly withdrawn instead of landed: the
# FENCE widening is INVISIBLE ON EVERY BOARD. Measured as a one-variable A/B on one tree (base origin/main
# 8691682f2 vs base+change), the SNOBOL4 rungs, the demo set, Icon, Prolog and Snocone are ALL BYTE-IDENTICAL
# between the arms -- same 1838/1839, same sole named red, same three stale XPASS, same 15 demo rows. A change
# with a zero delta on every board is indistinguishable from dead code UNTIL A WITNESS DEMANDS IT. These two
# witnesses are that demand: RED on clean main in both modes, GREEN with the change, emitted .s differing by 8
# lines. ⛔ Do not delete this gate because "the boards cover it". They measurably do not.
#
# ⛔⭐ WHY THIS CHANGE DOES NOT ALSO WIDEN THE ARBNO EXTENT IT SITS BESIDE -- hq_U's co-sign argument, recorded
# here because it is the one claim a zero delta CANNOT establish. choice_body_member's new extent line runs for
# EVERY C in the loop, so on its face it widens the already-landed ARBNO half too. It cannot: NOTHING REGISTERS
# AN ARBNO. All five fc_pair_extent_register call sites in lower_snobol4.c are three IR_MATCH_FENCE1 (1538, 1720,
# 1738) and two capture nodes (1665, 1689), so fc_pair_extent returns -1 for an ARBNO and the widening is inert
# there BY CONSTRUCTION. A board showing no delta cannot distinguish inert-here from inert-everywhere; this can.
#
# ⭐ WITNESSES vs CONTROLS. The 2 WITNESSES were each PROVEN RED on clean main. The 2 CONTROLS are green on
# BOTH arms by design -- the ARBNO twin (already cured on main; it must not regress) and a static FENCE with no
# dynamic operand (the change must not disturb the case it does not target). Never prune a control for being
# green; that is the mirror of narrowing a gate to its loudest symptom.
#
# The oracle is RUN, never hardcoded, so this gate cannot drift from SPITBOL. sbl needs -bf (case-sensitive,
# matching SCRIP) and a writable listing sink or it dumps its listing to stdout.
# ⛔ REFUSES rc=2 unless every witness is graded in BOTH modes, and rc=2 if the oracle is missing -- a board
# without an oracle prints a full, plausible, entirely false table.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSES (rc=2): lib_oracle_flags.sh not sourceable"; exit 2; }
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
SBL="/home/resources/x64/bin/sbl"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSES (rc=2): correctness oracle $SBL is missing"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
sink="$(sbl_listing_sink_flag "$d")" || { echo "⛔ GATE REFUSES (rc=2): no writable listing sink for sbl"; exit 2; }
mk() { printf '        &ANCHOR = 1\n        N = 2\n        P = %s\n        "%s" P                            :S(YES)F(NO)\nYES     OUTPUT = "MATCH" %s                :(END)\nNO      OUTPUT = "NOMATCH"\nEND\n' "$2" "$3" "$4" > "$d/$1.sno"; }
mk fence_body_dyn        'FENCE(LEN(N) "-") "Q"'        'ab-Q' '""'
mk fence_body_dyn_cap    'FENCE(LEN(N) $ X "-") "Q"'    'ab-Q' '" X=" X'
mk arbno_body_dyn_ctl    'ARBNO(LEN(N) "-") "Q"'        'ab-Q' '""'
mk fence_body_static_ctl 'FENCE(LEN(2) "-") "Q"'        'ab-Q' '""'
WITNESSES="fence_body_dyn fence_body_dyn_cap"
CONTROLS="arbno_body_dyn_ctl fence_body_static_ctl"
want_n=0; graded=0; bad=0
for w in $WITNESSES $CONTROLS; do
    want_n=$((want_n+2))
    want=$("$SBL" -bf "$sink" "$d/$w.sno" </dev/null 2>&1); orc=$?
    [ "$orc" = 0 ] && [ -n "$want" ] || { echo "⛔ GATE REFUSES (rc=2): oracle run for $w exited $orc -- cannot measure"; exit 2; }
    o=$(timeout -k 5 20 ./scrip "$d/$w.sno" </dev/null 2>&1); r=$?; graded=$((graded+1))
    [ "$r" = 0 ] && [ "$o" = "$want" ] || { echo "  ⛔ RED m3 $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-90)] -- oracle rc=0 out=[$(printf '%s' "$want" | tr '\n' '|')]"; bad=1; }
    if timeout -k 5 120 ./scrip --compile --out="$d/$w.s" "$d/$w.sno" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$w.s" -o "$d/$w.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 20 "$d/$w.m4" </dev/null 2>&1); r=$?; graded=$((graded+1))
        [ "$r" = 0 ] && [ "$o" = "$want" ] || { echo "  ⛔ RED m4 $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-90)] -- oracle rc=0 out=[$(printf '%s' "$want" | tr '\n' '|')]"; bad=1; }
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $w: does not compile/link"; bad=1
    fi
done
[ "$graded" = "$want_n" ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the $want_n required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [sno_fence_body_dynamic_operand]: graded $graded runs; see the RED lines above"; exit 1; }
echo "✅ GATE OK [sno_fence_body_dynamic_operand]: $graded runs match sbl -bf by VALUE -- $(set -- $WITNESSES; echo $#) witnesses (each proven RED on clean main 8691682f2) + $(set -- $CONTROLS; echo $#) controls (green on both arms BY DESIGN), both modes each"
