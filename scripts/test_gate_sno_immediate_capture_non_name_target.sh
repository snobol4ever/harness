#!/bin/bash
# SNOBOL4 IMMEDIATE deferred capture with a target that can never yield a name -- P $ *(N = N + 1) --
# must FAIL THE MATCH, not abort. SPITBOL evaluates the expression and then fails the match; SCRIP
# reached rt_assign_var with a value where a variable is required and died:
#   [IDX] BOMB rt_assign_var: lvalue is not a variable (dtype=3)   rc=134, core dumped
# Row snobol4-immediate-deferred-capture-with-a-non-name-target-bombs-instead-of-failing-the-match.
#
# ⭐ THE CONDITIONAL TWIN IS ALREADY CORRECT AND IS GRADED HERE AS A CONTROL ARM: P . *(N = N + 1)
# agrees with the oracle today (pattern_match.c, `strict && !by_name` sets rc=1 so the match fails
# at END). It is both the model for the cure and the thing a cure must not break -- if the immediate
# form is fixed by making every non-name target abort earlier, this arm goes red and says so.
#
# ⛔⭐⭐ WIDENED 2026-09-05 BY hq_S, AND THE REASON IS THE POINT OF THE INSTRUMENT: the two-witness
# version of this gate WENT GREEN ON A WRONG CURE. Giving the immediate arm the deferred arm's refusal
# and failing the node through the existing rt_cap_fail_retreat retreat path kills the core dump and
# prints NOMATCH -- and is wrong. Measured against sbl -bf: a target that FAILS makes the node RECEDE
# (unanchored, one evaluation per scan position, N=3), while a target that returns a VALUE ABORTS THE
# WHOLE MATCH (N=1 -- the scanner does not advance, an outer alternation is not tried, an ARB does not
# give back). Both print NOMATCH on the original anchored deterministic LEN(1) witness, so NOTHING in
# the two-witness gate could separate them; only the SIDE-EFFECT COUNT differs. The arms below exist to
# make that difference sayable. ⛔ Do not narrow this gate back to "it does not bomb".
#
# ⛔⭐ WITNESSES VERSUS CONTROLS -- READ THIS BEFORE YOU PRUNE A GREEN ARM. The 12 are two kinds and the
# distinction is load-bearing. The 8 WITNESSES were each PROVEN RED on clean main (measured 2026-09-05, SCRIP
# f3f8e252b, gate rc=1, 24 runs graded, 16 red runs) -- an arm that has never been red proves nothing about the
# property it claims. The 4 CONTROLS are GREEN ON MAIN **BY DESIGN** and must stay green after: they exist to
# catch a cure that OVER-REACHES, and the red-once test does not apply to them. ⛔ Do not delete a control for
# being green -- that is the same mistake as narrowing this gate to "it does not bomb", arriving from the other
# side. The measured near-miss they guard against is real: the first cure attempted here made every non-name
# target RETREAT, and `recede_when_target_fails` plus `conditional` are what would have caught the mirror-image
# error of making every non-name target abort earlier, which is the failure hq_B named when handing the row over.
#
# ⛔ AND THE NESTING ARMS ARE NOT DECORATION: a capture target may itself open a match, and the abort of
# an INNER match must not reach the outer one. The first cure passed n_nest_ok and n_nest_inner_ends and
# failed n_nest_inner_dies -- the discriminator is whether the inner match reaches its own END. Per-match
# state stamped with g_cap_gen is NOT enough on its own: nothing restores g_cap_gen across a nested match
# today (zeta_storage.c says head.capgen_save is restored through rt_match_ctx_restore; that function
# ignores its capgen argument entirely -- rtx_match.s). Routed to hq_U; this gate holds the line meanwhile.
#
# The expectation is not hardcoded: the oracle is RUN, so this gate cannot drift from it. sbl needs
# -bf (case-sensitive, matching SCRIP) and a writable listing sink, or it dumps its listing to stdout.
# ⛔ REFUSES rc=2 unless EVERY witness is graded in BOTH modes, and rc=2 if the oracle is absent or its
# own run fails -- a missing oracle prints a full, plausible, entirely false table.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSES (rc=2): lib_oracle_flags.sh not sourceable"; exit 2; }
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
SBL="/home/resources/x64/bin/sbl"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSES (rc=2): correctness oracle $SBL is missing -- a board without an oracle prints a false all-FAIL table"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
sink="$(sbl_listing_sink_flag "$d")" || { echo "⛔ GATE REFUSES (rc=2): no writable listing sink for sbl"; exit 2; }
# one-pattern witnesses: <anchor> <pattern text>.  N counts target evaluations, so a cure that RECEDES
# where SPITBOL ABORTS is caught by the printed N even though both spellings print NOMATCH.
mk1() { printf '        &ANCHOR = %s\n        N = 0\n        P = %s\n        "ABC" P                             :S(YES)F(NO)\nYES     OUTPUT = "MATCH"                    :(SHOW)\nNO      OUTPUT = "NOMATCH"\nSHOW    OUTPUT = "N=" N\nEND\n' "$1" "$2" > "$3"; }
mk1 0 'LEN(1) $ *(N = N + 1)'                       "$d/immediate.sno"
mk1 0 'LEN(1) . *(N = N + 1)'                       "$d/conditional.sno"
mk1 1 '(LEN(1) | LEN(2)) $ *(N = N + 1)'            "$d/abort_not_recede_alt.sno"
mk1 1 '(LEN(1) $ *(N = N + 1)) | LEN(2)'            "$d/abort_outer_alt_not_tried.sno"
mk1 1 'ARB $ *(N = N + 1) "C"'                      "$d/abort_no_arb_giveback.sno"
mk1 1 'ARBNO(LEN(1) $ *(N = N + 1)) RPOS(0)'        "$d/abort_no_arbno_iterate.sno"
mk1 0 'LEN(1) $ *((N = N + 1) EQ(1,2))'             "$d/recede_when_target_fails.sno"
mk1 1 'LEN(1) $ *(.N)'                              "$d/name_valued_is_not_by_name.sno"
mk1 1 'LEN(1) $ N'                                  "$d/plain_name_target_still_works.sno"
# nesting: the target opens a match of its own.  Q counts the INNER target's evaluations.
mkn() { printf '        &ANCHOR = 1\n        N = 0\n        Q = 0\n        DEFINE(%s)                       :(fe)\nf       %s\n        f = .N                              :(NRETURN)\nfe      P = LEN(1) $ *f()\n        "ABC" P                             :S(YES)F(NO)\nYES     OUTPUT = "MATCH"                    :(SHOW)\nNO      OUTPUT = "NOMATCH"\nSHOW    OUTPUT = "N=" N " Q=" Q             :(END)\nEND\n' "'f()'" "$1" > "$2"; }
mkn '"XY" LEN(1) . Z'                               "$d/nest_ok.sno"
mkn '"XY" LEN(1) $ *(Q = Q + 1)'                    "$d/nest_inner_aborts_reaches_end.sno"
mkn '"XY" LEN(1) $ *(Q = Q + 1) "Z"'                "$d/nest_inner_aborts_never_reaches_end.sno"
# WITNESSES -- each proven RED on clean main; a cure must turn every one of them green.
WITNESSES="immediate abort_not_recede_alt abort_outer_alt_not_tried abort_no_arb_giveback abort_no_arbno_iterate name_valued_is_not_by_name nest_inner_aborts_reaches_end nest_inner_aborts_never_reaches_end"
# CONTROLS -- green on main AND green after; they fail only if a cure over-reaches. Never prune one for being green.
CONTROLS="conditional recede_when_target_fails plain_name_target_still_works nest_ok"
want_n=0; graded=0; bad=0
for w in $WITNESSES $CONTROLS; do
    want_n=$((want_n+2))
    want=$("$SBL" -bf "$sink" "$d/$w.sno" </dev/null 2>&1); orc=$?
    [ "$orc" = 0 ] && [ -n "$want" ] || { echo "⛔ GATE REFUSES (rc=2): oracle run for $w exited $orc -- cannot measure"; exit 2; }
    o=$(timeout -k 5 20 ./scrip "$d/$w.sno" </dev/null 2>&1); r=$?; graded=$((graded+1))
    if [ "$r" != 0 ] || [ "$o" != "$want" ]; then
        echo "  ⛔ RED m3 $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-90)] -- oracle rc=0 out=[$(printf '%s' "$want" | tr '\n' '|')]"; bad=1
    fi
    if timeout -k 5 120 ./scrip --compile -o "$d/$w.s" "$d/$w.sno" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$w.s" -o "$d/$w.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 20 "$d/$w.m4" </dev/null 2>&1); r=$?; graded=$((graded+1))
        if [ "$r" != 0 ] || [ "$o" != "$want" ]; then
            echo "  ⛔ RED m4 $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-90)] -- oracle rc=0 out=[$(printf '%s' "$want" | tr '\n' '|')]"; bad=1
        fi
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $w: does not compile/link"; bad=1
    fi
done
[ "$graded" = "$want_n" ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the $want_n required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [sno_immediate_capture_non_name_target]: graded $graded runs; see the RED lines above"; exit 1; }
echo "✅ GATE OK [sno_immediate_capture_non_name_target]: $graded runs match sbl -bf by VALUE -- $(set -- $WITNESSES; echo $#) witnesses (each proven RED on clean main) + $(set -- $CONTROLS; echo $#) controls (green on main BY DESIGN, they catch an over-reaching cure), both modes each"
