#!/usr/bin/env bash
# test_gate_sno_goto_field_call_parses.sh -- A FUNCTION CALL IN THE SNOBOL4 GOTO FIELD PARSES, in both modes.
#
# WHAT THIS IS: the parse-level regression pin for the goto-field call construct -- :(GO()), :(RET('C2')),
# :S(PR(6,W V)) -- landed by hq_P 2026-09-05 (row snobol4-goto-field-function-call-is-invoked-by-name-and-
# scrip-is-exactly-inverted; FINDING-2026-09-05-hq_P-goto-field-call-is-by-name-and-the-six-m4-buildfail-
# xfails-are-five-mechanisms.md). Before that landing every one of these forms died at PARSE time, which is
# what hid the real defect underneath for as long as it did.
#
# ⛔⭐ WHAT THIS GATE DELIBERATELY DOES NOT GRADE, AND WHY THE OMISSION IS THE POINT: it does not assert what
# the construct DOES at run time. When this gate was written SCRIP was INVERTED against SPITBOL there -- it
# accepted the two value-return forms the oracle raises ERROR 021 on, and refused with ERROR 239 the NRETURN
# form the oracle accepts -- and pinning that behaviour here would have converted a documented gap into a
# green gate that must be edited before the cure could land: a test that defends a bug.
# ✅ THE INVERSION IS CURED (hq_P 2026-09-06, same row) and its end state is pinned by its OWN gate,
# test_gate_sno_goto_field_call_is_by_name.sh -- NRETURN name is the target, a value return raises ERROR 021,
# both modes. The split still stands on purpose: THIS gate stays parse-only, so a parser regression and a
# semantics regression cannot present as one red. Keep the two separate.
#
# ⭐ THE THIRD CASE IS THE ONE NOBODY WOULD THINK TO WRITE, so it is here on purpose: a user function named
# S or F. The lexer's <GT>[Ss]/"(" and <GT>[Ff]/"(" rules returned the success/failure goto markers at ANY
# paren depth, so :(F()) lexed F as T_GOTO_F and the construct was unreachable for those two names alone.
# Found only because the first hand-probe happened to be called F. Now guarded on gt_depth > 0.
#
# EXIT: 0 every form parses in both modes. 1 a form regressed to a parse error. 2 UNPROVEN (no built scrip).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_gate.sh -- the ONE gate-honesty authority." >&2; exit 3; }
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require_fresh "$ROOT" src "$SCRIP" "$RT/libscrip_rt.so"
T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
printf "        DEFINE('GOF()')                 :(MAIN)\nGOF     GOF  =  .L3                     :(NRETURN)\nMAIN    OUTPUT  =  'a'                   :(GOF())\nL3      OUTPUT  =  'b'\nEND\n"                > "$T/zeroarg.sno"
printf "        DEFINE('RETX(NEXT)')            :(MAIN)\nRETX    RETX  =  .L3                    :(NRETURN)\nMAIN    OUTPUT  =  'a'                   :(RETX('L3'))\nL3      OUTPUT  =  'b'\nEND\n" > "$T/strarg.sno"
printf "        DEFINE('PR(N,W)')               :(MAIN)\nPR      PR  =  .L3                      :(NRETURN)\nMAIN    W  =  'x'\n        OUTPUT  =  'a'                   :(PR(6,W W))\nL3      OUTPUT  =  'b'\nEND\n" > "$T/multiarg.sno"
printf "        DEFINE('F()')                   :(MAIN)\nF       F  =  .L3                       :(NRETURN)\nMAIN    OUTPUT  =  'a'                   :(F())\nL3      OUTPUT  =  'b'\nEND\n"     > "$T/fnamed.sno"
printf "        DEFINE('S()')                   :(MAIN)\nS       S  =  .L3                       :(NRETURN)\nMAIN    OUTPUT  =  'a'                   :(S())\nL3      OUTPUT  =  'b'\nEND\n"     > "$T/snamed.sno"
bad=0
for w in zeroarg strarg multiarg fnamed snamed; do
    for m in m3 m4; do
        if [ "$m" = m3 ]; then out="$("$SCRIP" "$T/$w.sno" < /dev/null 2>&1)"; else out="$("$SCRIP" --compile -o "$T/$w.s" "$T/$w.sno" < /dev/null 2>&1)"; fi
        case "$out" in
            *"parse error"*|*"no code generated"*) echo "  RED  $w $m -- the goto-field call REGRESSED to a parse error: $(echo "$out" | head -1)"; bad=1 ;;
            *) echo "  ok   $w $m parses" ;;
        esac
    done
done
if [ "$bad" -ne 0 ]; then echo "GATE RED(1) [sno-goto-field-call-parses]: a goto-field call form no longer parses -- the construct landed 2026-09-05 and something took it back out"; exit 1; fi
echo "GATE GREEN(0) [sno-goto-field-call-parses]: all 5 forms x 2 modes parse (run-time semantics are pinned separately by test_gate_sno_goto_field_call_is_by_name.sh)"
