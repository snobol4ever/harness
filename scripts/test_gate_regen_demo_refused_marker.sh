#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_regen_demo_refused_marker.sh -- THE ACCEPTANCE GATE for the demo regen's construct-ladder REFUSED arm.
#
# WHAT IT PROVES, hermetically, in BOTH directions on one tree (the row's DONE-WHEN):
#   (a) REFUSE -> MARKER : a *.pl under corpus/demos/prolog/** whose --compile refuses with the ladder's
#       'is not on the ladder yet' line has its committed .s REPLACED by <name>.s.REFUSED naming the rung.
#       A pre-cut .s carrying by-name rt_call_arr_bl calls must NOT survive the run.
#   (b) MARKER -> REAL .s: the same script, on a program that DOES compile today, deletes the stale marker
#       and writes real asm -- so the marker is self-retiring the first run after its rung lands.
#   (c) The graceful-skip is NOT collateral damage: the 21 sanctioned SNOBOL4 demo names still regenerate.
#   (d) Nested trees are covered (family_net/ is a real nested demo dir) -- enumerate-by-search, not by roster.
#
# ⛔ HERMETIC BY CONSTRUCTION: it builds a throwaway CORPUS under mktemp and never touches the real corpus, so it
# is safe to run at any time and cannot commit anything (the script under test skips its commit block on a non-repo).
# ⛔ THE SANCTIONED LIST IS READ OUT OF THE SCRIPT UNDER TEST, never re-typed here: a gate that keeps its own copy of
# the roster drifts away from the thing it guards, and then both are wrong together -- the guard-and-its-own-canary
# failure mode this project has already paid for twice (util_oracle_flag_sweep.sh, test_gate_argnote_sweep.sh).
# SUT= overrides the script under test (used to prove the gate FAILS against the pre-cure script -- fail-once).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SUT="${SUT:-$HERE/util_regen_demo_s_artifacts.sh}"
SCRIP="${SCRIP:-$ROOT/scrip}"
refuse() { echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "scrip not built at $SCRIP (a gate that cannot measure REFUSES, never skips-as-success)"
[ -f "$SUT" ]   || refuse "script under test not found: $SUT"
# Read the sanctioned roster straight out of the script under test.
demos_decl="$(sed -n '/^DEMOS="/,/"[[:space:]]*$/p' "$SUT")"
[ -n "$demos_decl" ] || refuse "could not read the DEMOS= roster out of $SUT (its declaration shape changed; this gate must be re-taught, not skipped)"
eval "$demos_decl" || refuse "the DEMOS= roster in $SUT did not evaluate"
[ -n "${DEMOS:-}" ] || refuse "the DEMOS= roster in $SUT evaluated empty"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/demos/snobol4" "$T/demos/prolog/sub"
for f in $DEMOS; do printf '\tOUTPUT = "stub"\nEND\n' > "$T/demos/snobol4/$f.sno"; done
# (a) a refuser with a PRE-CUT .s carrying the very by-name calls the row measured (214 across four demo artifacts)
printf ':- initialization(main).\nmain :- findall(X, member(X,[1,2]), L), write(L), nl.\n' > "$T/demos/prolog/refuser.pl"
printf '\t.text\n\tcall rt_call_arr_bl\n\tcall rt_call_arr_bl\n' > "$T/demos/prolog/refuser.s"
# (d) nested, and a different rung, so the marker text is proven to name the rung it actually hit
printf ':- initialization(main).\nmain :- nb_setval(k, 1), write(ok), nl.\n' > "$T/demos/prolog/sub/refuser2.pl"
printf '\t.text\n\tcall rt_call_arr_bl\n' > "$T/demos/prolog/sub/refuser2.s"
# (b) a program that DOES compile today, carrying a stale marker from before its rung landed
printf ':- initialization(main).\nmain :- write(hello), nl.\n' > "$T/demos/prolog/compiles.pl"
printf 'REFUSED by the construct ladder -- stale, from before this rung landed\n' > "$T/demos/prolog/compiles.s.REFUSED"
echo "=== running $(basename "$SUT") against a throwaway corpus ==="
CORPUS="$T" SCRIP="$SCRIP" bash "$SUT" gate-selftest > "$T/run.log" 2>&1; run_rc=$?
sed 's/^/    /' "$T/run.log"
fails=0
ck() { if eval "$2"; then echo "  ✅ $1"; else echo "  ⛔ FAIL $1"; fails=$((fails+1)); fi; }
echo "=== assertions ==="
ck "script exited 0 (got $run_rc)"                                   '[ "$run_rc" -eq 0 ]'
ck "(a) refuser.s DELETED (a pre-cut snapshot must not survive)"     '[ ! -e "$T/demos/prolog/refuser.s" ]'
ck "(a) refuser.s.REFUSED written"                                   '[ -s "$T/demos/prolog/refuser.s.REFUSED" ]'
ck "(a) marker names the rung it hit (rung 8, findall)"              'grep -q "rung 8 lands it" "$T/demos/prolog/refuser.s.REFUSED"'
ck "(d) nested sub/refuser2.s DELETED"                               '[ ! -e "$T/demos/prolog/sub/refuser2.s" ]'
ck "(d) nested marker names ITS rung (rung 10, nb_setval)"           'grep -q "rung 10 lands it" "$T/demos/prolog/sub/refuser2.s.REFUSED"'
ck "(b) compiles.s written as REAL asm"                              'grep -qE "^[[:space:]]*\.(intel_syntax|text|globl)" "$T/demos/prolog/compiles.s"'
ck "(b) stale compiles.s.REFUSED RETIRED by the real .s"             '[ ! -e "$T/demos/prolog/compiles.s.REFUSED" ]'
ck "ZERO rt_call_arr_bl under the regenerated prolog demo tree"      '[ "$(grep -rho rt_call_arr_bl "$T/demos/prolog" 2>/dev/null | wc -l)" -eq 0 ]'
ck "(c) sanctioned SNOBOL4 arm still regenerates (roman.s real asm)" 'grep -qE "^[[:space:]]*\.(intel_syntax|text|globl)" "$T/demos/snobol4/roman.s"'
ck "(c) all $(printf %s "$DEMOS" | wc -w) sanctioned names produced a .s" '[ "$(ls "$T"/demos/snobol4/*.s 2>/dev/null | wc -l)" -eq "$(printf %s "$DEMOS" | wc -w)" ]'
echo "=================================================================="
if [ "$fails" -eq 0 ]; then echo "✅ GATE PASS: the demo regen carries the REFUSED arm in both directions (refuse->marker, marker->real .s)"; exit 0; fi
echo "⛔ GATE FAIL: $fails assertion(s) failed — the demo regen does NOT carry the construct-ladder REFUSED arm."; exit 1
