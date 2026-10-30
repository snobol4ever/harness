#!/usr/bin/env bash
# test_gate_pl_swi_copy_term_3_projects_freeze_when_and_clpfd_constraints_as_residual_goals_as_swipl.sh -- copy_term/3 RETURNS THE RESIDUAL GOALS OF ATTRIBUTED VARIABLES (ceo CEO-1930, hq_icon on the SWI umbrella; swipl 9.0.4; ARCH-PROLOG-CLPFD.md section 4 names copy_term/3 and term_attvars/2).
# copy_term(+Term, -Copy, -Gs) gives an attribute-free copy of Term and the goals that stand for the attributes: freeze/2 goals for a frozen variable, when/2 goals reconstructed from the suspension
# (a nested ground/nonvar disjunction or conjunction comes back as ONE when(Cond, Goal), printed once however many variables it waits on), the goals each module's attribute_goals//1 gives (clpfd
# through the library's own), and put_attr(V, Module, Value) for a module with none. term_attvars/2 follows the attribute values too, which is how a when(?=(X,Y), G) that waits on a hidden
# variable is found. SCRIP had no copy_term/3 (existence_error), so library/test_when nested_ground#1..3 read red in both modes.
# THE WITNESS (SWI dialect, selected by the use_module lines as the suite's files are): 24 labelled shapes, 48 lines of swipl's answer -- no attributed variable; freeze once, twice, on two variables, on a
# bound variable; when on ground, nonvar, ?=, a conjunction, a disjunction and three nesting depths of ground, a partly bound one, a fired one, two on one variable, one whose goal shares a variable;
# freeze with when on one variable; clpfd domains, a sum and a disequality; put_attr with no hook, two modules with no hook beside freeze; a variable only in the goal -- each printed with its
# variables numbered and operators ignored (SCRIP's operator table carries ?= as an infix operator for XSB; swipl's does not).
# ARMS: the oracle answers the whole witness (its last line is present; an oracle that cannot REFUSES rc 2), then mode 3 and mode 4 each equal it line for line.
# RED BEFORE (measured 2026-10-30 on the tree before the cure, mode 3): copy_term/3 raises existence_error at the first attributed shape; library/test_when read 0 of 3.
# NOT COVERED, KNOWN: an explicit M:attribute_goals or M:attr_unify_hook head in a file that is not a module loses its qualifier in the module pass (the hook registers under user); a DCG head
# written M:H --> B becomes a ':'/4 clause; both are separate defects and the library modules (clpfd) declare their hooks inside :- module, which works.
# rc 0 every arm holds; 1 an arm is red; 2 cannot measure.
GATE_NAME=test_gate_pl_swi_copy_term_3_projects_freeze_when_and_clpfd_constraints_as_residual_goals_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="$ROOT/SCRIP/scrip"
RT="${RT_DIR:-$ROOT/SCRIP/out}"
SWIPL=/usr/bin/swipl
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -x "$SWIPL" ] || refuse "no swipl oracle at $SWIPL"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
cat > "$TMPD/w.pl" <<'EOP'
:- use_module(library(lists)).
:- use_module(library(when)).
:- use_module(library(clpfd)).
:- initialization(main).
t(L, G) :- catch(( call(G) -> R = ok ; R = failed ), E, ( E = error(F, _) -> R = raised(F) ; R = threw(E) )), write(L), write(': '), write(R), nl.
show(Gs) :- \+ \+ ( numbervars(Gs, 0, _), write_term(Gs, [numbervars(true), quoted(true), ignore_ops(true)]), nl ).
cp(Term) :- copy_term(Term, Copy, Gs), show(Copy-Gs).
main :-
    t(no_attvars, cp(f(_, a, _))),
    t(freeze_one, ( freeze(A, true), cp(A) )),
    t(freeze_two, ( freeze(B, write(x)), freeze(B, write(y)), cp(B) )),
    t(freeze_two_vars, ( freeze(C1, true), freeze(C2, true), cp(f(C1, C2)) )),
    t(freeze_bound, ( freeze(D, true), D = 1, cp(D) )),
    t(when_ground, ( when(ground(E), true), cp(E) )),
    t(when_nonvar, ( when(nonvar(F), true), cp(F) )),
    t(when_determined, ( when(?=(G1, G2), true), cp(f(G1, G2)) )),
    t(when_conj, ( when((nonvar(H1), ground(H2)), true), cp(f(H1, H2)) )),
    t(when_disj, ( when((nonvar(I1) ; ground(I2)), true), cp(f(I1, I2)) )),
    t(when_nested1, ( when(ground(J1) ; (ground(J2), ground(J3)), true), cp(f(J1, J2, J3)) )),
    t(when_nested2, ( when(ground(K1) ; ((ground(K2), ground(K3)), ground(K4)), true), cp(f(K1, K2, K3, K4)) )),
    t(when_nested3, ( when(ground(L1) ; (((ground(L2), ground(L3)), ground(L4)), ground(L5)), true), cp(f(L1, L2, L3, L4, L5)) )),
    t(when_partly_bound, ( when((ground(M1), ground(M2)), true), M1 = 1, cp(f(M1, M2)) )),
    t(when_fired, ( when(ground(N), true), N = 1, cp(N) )),
    t(when_twice, ( when(nonvar(O), true), when(ground(O), true), cp(O) )),
    t(when_with_goal_var, ( when(ground(P), q(P, Z)), cp(f(P, Z)) )),
    t(freeze_and_when, ( freeze(Q, true), when(ground(Q), true), cp(Q) )),
    t(clpfd_dom, ( R #> 3, R #< 8, cp(R) )),
    t(clpfd_two, ( S #= T + U, T in 0..5, U in 0..5, cp(f(S, T, U)) )),
    t(clpfd_neq, ( V #\= W, V in 1..3, cp(f(V, W)) )),
    t(put_attr_plain, ( put_attr(X1, foo, bar), cp(X1) )),
    t(two_attr_modules, ( put_attr(X3, foo, 1), put_attr(X3, bar, 2), freeze(X3, true), cp(X3) )),
    t(var_only_in_goal, ( freeze(Y1, true), cp(g(Y1, Y1)) )),
    halt.
EOP
check() {
    local name="$1" got="$2"
    total=$((total+1))
    if [ "$got" = "$WANT" ]; then echo "  ok  $name"
    else echo "  RED $name: differs from swipl's answer:"; diff <(printf '%s\n' "$WANT") <(printf '%s\n' "$got") | head -8 | sed 's/^/      /'; red=$((red+1)); fi
}
WANT="$(timeout -k 5 30 "$SWIPL" -q "$TMPD/w.pl" </dev/null 2>&1)" || refuse "swipl could not run the witness"
[ "$(printf '%s\n' "$WANT" | tail -1)" = "var_only_in_goal: ok" ] || refuse "swipl did not answer the witness to its last line"
total=$((total+1)); echo "  ok  swipl answers the whole witness ($(printf '%s\n' "$WANT" | wc -l) lines)"
got_m3="$(timeout -k 5 120 "$SCRIP" "$TMPD/w.pl" </dev/null 2>&1)"
check "mode 3 equals swipl" "$got_m3"
if timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/w.s" "$TMPD/w.pl" </dev/null 2> "$TMPD/err" > /dev/null && gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$TMPD/err"; then
    got_m4="$(timeout -k 5 120 "$TMPD/w.bin" </dev/null 2>&1)"
else
    refuse "the mode-4 compile or link failed: $(head -c 200 "$TMPD/err")"
fi
check "mode 4 equals swipl" "$got_m4"
if [ "$red" = 0 ]; then echo "✅ GATE PASS [$GATE_NAME]: $total of $total arms hold"; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $red of $total arm(s) red"; exit 1
