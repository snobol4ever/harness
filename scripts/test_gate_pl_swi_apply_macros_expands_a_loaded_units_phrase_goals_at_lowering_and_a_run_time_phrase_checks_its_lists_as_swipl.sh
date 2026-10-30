#!/usr/bin/env bash
# test_gate_pl_swi_apply_macros_expands_a_loaded_units_phrase_goals_at_lowering_and_a_run_time_phrase_checks_its_lists_as_swipl.sh -- library(apply_macros) EXPANDS phrase GOALS WHEN A UNIT IS LOADED, AND THE RUN-TIME phrase CHECKS ITS LISTS (ceo CEO-1930, hq_icon on the SWI umbrella; the cto's ruling ARCH-PROLOG-DATABASE.md
# section 14; swipl 9.0.4). With the directive use_module(library(apply_macros)) in a unit, swipl rewrites a phrase/2,3 (and call_dcg/3) goal in a CLAUSE BODY when it is loaded: a terminal (the empty list,
# a proper list, a string) becomes a unification, a plain nonterminal the direct call with the two extra arguments and NO list check, a control construct (comma, semicolon, arrow, soft cut, braces,
# cut) or a partial list is left for the real phrase/3, which raises type_error(list, X) on an argument that is not a variable, a cons or []; expand_goal/2 and expand_term/2 give the same rewrites; a
# goal built and called through call/N is never rewritten, so it raises. SCRIP read a test body through call/1, so a static goal and a built one were one road (core/test_dcg's five reds). Now the
# lowerer rewrites under a per-unit fact the directive sets, the plunit shim compiles a test body of such a unit as a clause, and every run-time-lowered phrase calls the checking entry.
# THE WITNESS (SWI dialect, the unit loads apply_macros as the suite file does): 41 labelled shapes, 73 lines of swipl's answer -- expand_goal and expand_term of every rewrite and of every shape it
# leaves alone (a variable nonterminal, control constructs, a partial list, a goal inside a conjunction and a findall), then static body goals of each kind (terminals and plain nonterminals fail without a
# check; control constructs, partial lists and an unbound rule raise) and the built goals through call/N, findall, once and =.. -- each answered as `Label: ok|failed|raised(Formal)`.
# ARMS: the oracle answers the whole witness (its last line is present; an oracle that cannot REFUSES rc 2), then mode 3 and mode 4 each equal its STDOUT line for line (swipl's singleton warnings go
# to stderr and are not compared).
# RED BEFORE (measured 2026-10-30 on the tree before the cure): core/test_dcg read 37 of 42 in m3 and m4; this witness differs from swipl in m3 on the expansion forms and the checked forms.
# NOT COVERED, KNOWN: a clause ASSERTED at run time runs its phrase goals through the fragment evaluator, which calls the nonterminal directly (swipl: assert does not expand, so a bad list raises); a unit
# CONSULTED at run time takes the run-time road; the other apply_macros rewrites (maplist, forall, once, ignore, aggregate) are not done -- none is rowed (ARCH-PROLOG-DATABASE.md 14.2 (d)).
# rc 0 every arm holds; 1 an arm is red; 2 cannot measure.
GATE_NAME=test_gate_pl_swi_apply_macros_expands_a_loaded_units_phrase_goals_at_lowering_and_a_run_time_phrase_checks_its_lists_as_swipl
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
:- use_module(library(apply_macros), []).
show(T) :- \+ \+ ( numbervars(T, 0, _), write_term(T, [numbervars(true), quoted(true), ignore_ops(true)]), nl ).
x(L, G) :- t(L, ( G, show(G) )).
t(L, G) :- catch(( call(G) -> R = ok ; R = failed ), E, ( E = error(F, _) -> R = raised(F) ; R = threw(E) )), write(L), write(': '), print(R), nl.
:- initialization(main).
foo([x|T], T).
s_list :- phrase([], a).
s_nt_bad :- phrase(foo, a).
s_nt_ok :- phrase(foo, [x]).
s_str :- phrase("ab", [a,b]).
s_terms :- phrase([a,b], [a,b]).
s_terms_bad :- phrase([a,b], c).
s_conj_bad :- phrase((foo, foo), a).
s_conj_ok :- phrase((foo, [y]), [x,y]).
s_alt_bad :- phrase(([x] ; [y]), a).
s_alt_ok :- phrase(([x] ; [y]), [y]).
s_ite_bad :- phrase(([x] -> [y] ; [z]), a).
s_curly_bad :- phrase({true}, a).
s_curly_ok :- phrase({true}, []).
s_cut_bad :- phrase(!, a).
s_conj3_rest_bad :- phrase((foo, foo), [x,x], b).
s_conj3_ok :- phrase((foo, foo), [x,x], R), R == [].
digits([D|T]) --> [D], { code_type(D, digit) }, digits(T).
digits([]) --> [].
main :-
    t(eg_nt, ( expand_goal(phrase(a, L1), G1), show(G1) )),
    t(eg_nt3, ( expand_goal(phrase(a, L2, R2), G2), show(G2) )),
    t(eg_args, ( expand_goal(phrase(spec(_, []), S3), G3), show(G3) )),
    t(eg_var_nt, ( expand_goal(phrase(V4, V4), G4), show(G4) )),
    t(eg_var_nt3, ( expand_goal(phrase(V5, V5, V5), G5), show(G5) )),
    t(eg_plain_goal, ( expand_goal(quoniam, G6), show(G6) )),
    t(eg_nil, ( expand_goal(phrase([], L7), G7), show(G7) )),
    t(eg_list, ( expand_goal(phrase([a,b], L8, R8), G8), show(G8) )),
    t(eg_string, ( expand_goal(phrase("ab", L9, R9), G9), show(G9) )),
    t(eg_partial, ( expand_goal(phrase([a|T10], L10), G10), show(G10) )),
    t(eg_conj, ( expand_goal(phrase((a, b), L11), G11), show(G11) )),
    t(eg_alt, ( expand_goal(phrase((a ; b), L12), G12), show(G12) )),
    t(eg_curly, ( expand_goal(phrase({x}, L13), G13), show(G13) )),
    t(eg_qualified, ( expand_goal(phrase(m:foo, L14), G14), show(G14) )),
    t(eg_inside_conj, ( expand_goal((phrase(a, L15), true), G15), show(G15) )),
    t(eg_inside_findall, ( expand_goal(findall(X16, phrase(a, X16), _), G16), show(G16) )),
    t(et_clause, ( expand_term((p17 :- phrase(b, [1])), R17), show(R17) )),
    t(et_clause2, ( expand_term((alleq(Xs1) :- phrase(spec(Xs2, []), Xs1), alleq(Xs2)), R18), show(R18) )),
    t(et_control_clause, ( expand_term((p19(X19) :- phrase((a, b), X19)), R19), show(R19) )),
    t(s_list, s_list), t(s_nt_bad, s_nt_bad), t(s_nt_ok, s_nt_ok), t(s_str, s_str), t(s_terms, s_terms), t(s_terms_bad, s_terms_bad),
    t(s_conj_bad, s_conj_bad), t(s_conj_ok, s_conj_ok), t(s_alt_bad, s_alt_bad), t(s_alt_ok, s_alt_ok), t(s_ite_bad, s_ite_bad),
    t(s_curly_bad, s_curly_bad), t(s_curly_ok, s_curly_ok), t(s_cut_bad, s_cut_bad), t(s_conj3_rest_bad, s_conj3_rest_bad), t(s_conj3_ok, s_conj3_ok),
    t(dyn_list, ( G = phrase([],a), call(G) )),
    t(dyn_list3, ( G3 = phrase([],a,[]), call(G3) )),
    t(dyn_partial, ( G2 = phrase([], [a|b]), call(G2) )),
    t(dyn_rest, ( G4 = phrase([], [], a), call(G4) )),
    t(dyn_rest_partial, ( G5 = phrase([], [], [a|b]), call(G5) )),
    t(dyn_var, ( G6 = phrase([], _), call(G6) )),
    t(dyn_string, ( G7 = phrase([], "abc"), call(G7) )),
    t(dyn_nt, ( G8 = phrase(foo, a), call(G8) )),
    t(dyn_nt_ok, ( G9 = phrase(foo, [x]), call(G9) )),
    t(dyn_nt_rest_bad, ( G10 = phrase(foo, [x], b), call(G10) )),
    t(dyn_control, ( G11 = phrase((foo, foo), a), call(G11) )),
    t(dyn_control_ok, ( G12 = phrase(([x]; [y]), [y]), call(G12) )),
    t(dyn_digits, ( G13 = phrase(digits(Ds), `12`), call(G13), Ds == `12` )),
    t(dyn_built, ( Name = phrase, G14 =.. [Name, [], a], call(G14) )),
    t(dyn_findall, ( G15 = phrase([], a), findall(x, G15, _) )),
    t(dyn_once, ( G16 = phrase([], a), once(G16) )),
    t(dyn_unbound_rule, ( G17 = phrase(_, a), call(G17) )),
    t(dyn_unbound_rule_ok, ( G18 = phrase(_, []), call(G18) )),
    t(dyn_noncallable, ( G19 = phrase(27, []), call(G19) )),
    halt.
EOP
check() {
    local name="$1" got="$2"
    total=$((total+1))
    if [ "$got" = "$WANT" ]; then echo "  ok  $name"
    else echo "  RED $name: differs from swipl's answer:"; diff <(printf '%s\n' "$WANT") <(printf '%s\n' "$got") | head -8 | sed 's/^/      /'; red=$((red+1)); fi
}
WANT="$(timeout -k 5 30 "$SWIPL" -q "$TMPD/w.pl" </dev/null 2>/dev/null)" || refuse "swipl could not run the witness"
[ "$(printf '%s\n' "$WANT" | tail -1)" = "dyn_noncallable: raised(type_error(callable,27))" ] || refuse "swipl did not answer the witness to its last line"
total=$((total+1)); echo "  ok  swipl answers the whole witness ($(printf '%s\n' "$WANT" | wc -l) lines)"
got_m3="$(timeout -k 5 120 "$SCRIP" "$TMPD/w.pl" </dev/null 2>/dev/null)"
check "mode 3 equals swipl" "$got_m3"
if timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/w.s" "$TMPD/w.pl" </dev/null 2> "$TMPD/err" > /dev/null && gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$TMPD/err"; then
    got_m4="$(timeout -k 5 120 "$TMPD/w.bin" </dev/null 2>/dev/null)"
else
    refuse "the mode-4 compile or link failed: $(head -c 200 "$TMPD/err")"
fi
check "mode 4 equals swipl" "$got_m4"
if [ "$red" = 0 ]; then echo "✅ GATE PASS [$GATE_NAME]: $total of $total arms hold"; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $red of $total arm(s) red"; exit 1
