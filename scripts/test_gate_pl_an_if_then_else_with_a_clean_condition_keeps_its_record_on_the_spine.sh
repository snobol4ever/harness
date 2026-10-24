#!/usr/bin/env bash
# test_gate_pl_an_if_then_else_with_a_clean_condition_keeps_its_record_on_the_spine.sh -- D3 KIND 7 (hq_snobol4, 2026-10-24, on the cfo's ruling of 16:15 and his correction of
# 16:39; CEO-1945/1946/1951): AN IF-THEN-ELSE OR NEGATION BOUND WHOSE CONDITION SPAN CARRIES NO EXCURSION (no retaining call, generator, suspend, disjunction or cut between the BOUND and
# its UNMARKs -- planner_bound_spine, the one decider) CARVES ITS RECORD ON THE SPINE (mark, saved rsp, banked B, the choice header: the cell-shape row pl_bound_spine, K 48), the fence
# and the condition's failure read it at the plan's distance and pop it, the arm-failure road (pl_lower_ite's unmk_c, ival bit 32) reads nothing of it, and every other BOUND keeps
# its record in the activation frame as before. TWO ARMS: (i) the [HOMES] row of the BOUND of q/1 below reads home=SPINE (the frame regime printed home=NONE: red on 005253b63);
# (ii) every cell, compiled whole, agrees with swipl in m3 and m4 (expectations CUT FROM THE ORACLE at run time) -- two ites in a row whose second takes its else arm and a
# variable hosted in the BOUND's carve read after the construct are the shapes that broke while the cure was built; a double negation after a retaining call (the
# outer BOUND's condition holds the inner BOUND: XsbTests delay_tests_fa, get_residual/2's \+ \+ V=G, segfaulted on 275416cf5) and a tabled negation are the arms CEO-1960 added. FAIL_ONCE=1 corrupts the first expectation. rc 0 green, 1 red,
# 2 could not measure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; RT_DIR="${RT_DIR:-$ROOT/out}"
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ GATE REFUSE(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SWI="$(swipl_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: no swipl -- every expectation is cut from the oracle"; exit 2; }
[ -x "$SCRIP" ] && [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip or runtime"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
CELLS=(
"ite_then_and_else|q(X) :- ( X > 1 -> Y = big ; Y = small ), write(Y), nl. main :- q(0), q(5)."
"two_ites_second_takes_else|main :- A = 1, ( A == 1 -> write(s) ; write(n) ), nl, ( A == o -> write(al) ; write(ind) ), nl, C = [H|T], numbervars(C, 0, _), write(C), nl."
"copy_term_after_two_ites|main :- copy_term(f(X,X), f(A,B)), ( A == B -> write(s) ; write(n) ), nl, X = o, ( A == o -> write(al) ; write(ind) ), nl, copy_term([H|T], C), numbervars(C, 0, _), write(C), nl."
"then_arm_binds_and_fails_in_an_outer_choice|main :- X = Z, Y = W, ( ( X = 1 -> Y = 2, fail ; true ) ; write(outer) ), nl, ( var(X) -> write(xfree) ; write(xbound) ), nl, ( var(W) -> write(wfree) ; true ), nl."
"negation_body_binds_and_fails|p(1). p(2). main :- \\+ ( X = 1, fail ), write(neg_ok), nl, ( \\+ p(7) -> write(nop7) ; write(p7) ), nl."
"retaining_condition_stays_in_the_frame|p(1). p(2). p(3). main :- ( p(X), X > 1 -> write(X) ; write(none) ), nl."
"retaining_then_arm|p(1). p(2). p(3). main :- ( true -> p(X) ; X = 0 ), write(X), nl, X >= 2, !."
"ite_inside_findall|p(1). p(2). p(3). main :- findall(Z, ( p(Z), ( Z > 1 -> true ; fail ) ), L), write(L), nl."
"once_and_ignore|p(1). p(2). main :- ( once(p(A)) -> write(A) ; true ), nl, ( ignore(p(9)) -> write(ign) ; true ), nl."
"double_negation_after_a_retaining_call|main :- member(X, [b,a,c]), \\+ \\+ X = a, member(Y, [1,2]), write(X-Y), nl, fail. main."
"tabled_double_negation_and_tnot|:- table p/1. p(X) :- member(X, [1,2,3]), \\+ \\+ X = 2. :- table q/1. q(X) :- member(X, [a,b]), tnot(r(X)). :- table r/1. r(b). main :- findall(X, p(X), L), write(L), nl, findall(Y, q(Y), M), write(M), nl."
)
swi() { ( cd "$T" && timeout -k 5 20s "$SWI" -q -g halt -t halt "$1" </dev/null 2>/dev/null ); }
run3() { ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" "$1" </dev/null 2>/dev/null ); }
run4() { ( cd "$T" && SCRIP="$SCRIP" LIBRT="$RT_DIR/libscrip_rt.so" timeout -k 5 40s bash "$HERE/run_prolog_via_x86_backend.sh" "$T/$1" </dev/null 2>/dev/null ); }
RC=0; N=0; A3=0; A4=0; BAD=""; FIRST=1
for c in "${CELLS[@]}"; do n="${c%%|*}"; body="${c#*|}"; f="$n.pl"
  printf ':- initialization(main).\n%s\n' "$body" > "$T/$f"
  want="$(swi "$f")"; [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: swipl printed nothing for cell $n ($body)"; exit 2; }
  [ -n "${FAIL_ONCE:-}" ] && [ "$FIRST" = 1 ] && want="$want corrupted by FAIL_ONCE"; FIRST=0
  N=$((N + 1)); g3="$(run3 "$f")"; g4="$(run4 "$f")"
  if [ "$g3" = "$want" ]; then A3=$((A3 + 1)); else RC=1; BAD="$BAD
      m3 $n: swipl [$(echo "$want" | tr '\n' ' ')] scrip [$(echo "$g3" | tr '\n' ' ' | cut -c1-80)]"; fi
  if [ "$g4" = "$want" ]; then A4=$((A4 + 1)); else RC=1; BAD="$BAD
      m4 $n: swipl [$(echo "$want" | tr '\n' ' ')] scrip [$(echo "$g4" | tr '\n' ' ' | cut -c1-80)]"; fi
done
SP="$( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 60s "$SCRIP" --dump-homes --compile -o /dev/null ite_then_and_else.pl </dev/null 2>&1 | grep -E '^\[HOMES\] .* graph=q/1 .* kind=IR_BOUND ' | grep -c ' home=SPINE ' )"
if [ "$SP" -lt 1 ]; then RC=1; BAD="$BAD
      homes: the BOUND of q/1 (a clean condition) is not home=SPINE"; fi
echo "  blocking: m3 $A3 of $N cells agree with swipl; m4 $A4 of $N; spine BOUNDs in q/1: $SP (want 1)"
[ -n "$BAD" ] && printf '  ⛔ failing:%s\n' "$BAD" | head -30
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N cells in m3 and m4, a clean-condition if-then-else keeps its record on the spine"
else echo "GATE FAIL(1) [$G]: $((N - A3)) m3 and $((N - A4)) m4 cells disagree with swipl, spine BOUNDs $SP"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) oracle: $SWI measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
