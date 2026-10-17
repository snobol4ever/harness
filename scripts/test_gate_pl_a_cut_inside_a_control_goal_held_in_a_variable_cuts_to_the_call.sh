#!/usr/bin/env bash
# test_gate_pl_a_cut_inside_a_control_goal_held_in_a_variable_cuts_to_the_call.sh -- A CUT NESTED UNDER , ; -> *-> IN A
# GOAL CALLED THROUGH A VARIABLE CUTS BACK TO THAT CALL, AS ISO call/1 (7.8.3) REQUIRES (row prolog-a-cut-inside-a-control-
# goal-held-in-a-variable-is-local-to-the-generic-functor-wrapper-not-the-call; cure ruled by the cto 2026-10-01).
# RED BEFORE: G = (member(Y,[1,2,3]), (Y >= 2 -> ! ; true)), findall(Y, G, L) gave [1,2,3] in both modes (swipl [1,2]) and
# the length/2 generator form ran out of stack: the synthesized ,/2 ;/2 ->/2 default bodies meta-called each operand, so a
# cut beneath an if-then-else was local to one nested default activation. The cure: those defaults try '$cutcall'/2 first
# (after ,/2's own $fc clause), which compiles the goal once as the body of a fresh clause over its own variables and calls
# it, so the cut is that clause's own cut. ARMS cover the cut in a then branch, an else branch, a (C, ! ; E) arm, an unbounded
# generator, a forall, and the two that must NOT change: a cut inside \+ stays local, a cut-free goal keeps every answer.
# The ref is cut from swipl at run time; m3 and m4 must each equal it byte for byte. rc 0 GREEN, 1 RED, 2 REFUSED.
set -u
GATE_NAME=test_gate_pl_a_cut_inside_a_control_goal_held_in_a_variable_cuts_to_the_call
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"; SWIPL="${SWIPL:-/usr/bin/swipl}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make"
[ -x "$SWIPL" ] || refuse "no swipl oracle at $SWIPL -- the ref is cut from the oracle at run time or not at all"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pl" <<'EOP'
:- initialization(main).
main :-
    G1 = (member(A, [1,2,3]), (A >= 2 -> ! ; true)), findall(A, G1, L1), writeq(then_cut(L1)), nl,
    G2 = (member(B, [1,2,3]), (B >= 2, ! ; true)), findall(B, call(G2), L2), writeq(arm_cut(L2)), nl,
    findall(N, (G3 = (length(_, N), (N >= 2 -> ! ; true)), call(G3)), L3), writeq(generator_cut(L3)), nl,
    G4 = (member(C, [1,2,3]), (C >= 2 -> true ; !)), findall(C, G4, L4), writeq(else_cut(L4)), nl,
    G5 = (member(D, [1,2,3]), (D >= 2 -> ! ; true)), forall(call(G5), (write(D), write(' '))), nl,
    G6 = (member(E, [1,2,3]), \+ \+ !), findall(E, G6, L6), writeq(negation_keeps_cut_local(L6)), nl,
    G7 = (member(F, [1,2,3]), true ; F = 0), findall(F, G7, L7), writeq(cut_free_keeps_all(L7)), nl,
    halt.
EOP
want="$(timeout -k 5 30 "$SWIPL" -q "$T/w.pl" < /dev/null 2>&1)" || refuse "swipl did not run the witness"
[ -n "$want" ] || refuse "swipl printed nothing for the witness"
red=0
m3="$(timeout -k 5 60 "$SCRIP" "$T/w.pl" < /dev/null 2>&1)"
if [ "$m3" = "$want" ]; then echo "  ok  m3 equals swipl"; else echo "  RED m3 differs from swipl:"; diff <(echo "$want") <(echo "$m3") | sed 's/^/      /'; red=$((red+1)); fi
if timeout -k 5 60 "$SCRIP" --compile "$T/w.pl" -o "$T/w.s" < /dev/null > "$T/c.err" 2>&1 && gcc -m64 "$T/w.s" -o "$T/w4" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" > /dev/null 2>&1; then
    m4="$(timeout -k 5 60 "$T/w4" < /dev/null 2>&1)"
    if [ "$m4" = "$want" ]; then echo "  ok  m4 equals swipl"; else echo "  RED m4 differs from swipl:"; diff <(echo "$want") <(echo "$m4") | sed 's/^/      /'; red=$((red+1)); fi
else echo "  RED m4 did not compile/link:"; sed -n '1,5p' "$T/c.err" | sed 's/^/      /'; red=$((red+1)); fi
if [ "$red" -eq 0 ]; then echo "✅ GATE GREEN [$GATE_NAME]: a cut under , ; -> *-> in a variable goal cuts to the call, both modes (7 arms)"; exit 0; fi
echo "⛔ GATE RED [$GATE_NAME]: $red mode(s) differ from swipl"; exit 1
