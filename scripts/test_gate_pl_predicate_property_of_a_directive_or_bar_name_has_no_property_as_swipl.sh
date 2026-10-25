#!/bin/bash
# test_gate_pl_predicate_property_of_a_directive_or_bar_name_has_no_property_as_swipl.sh -- ?-, :- AND | ARE NOT PREDICATES IN THE SWI DIALECT (hq_packages, ceo CEO-1959; Trealla issues_test1071 prints
# whether predicate_property('?-'(_,_), _) holds: swipl 9.0.4 and 10.1.5 say it does not). swipl reports NO property for ?-/1, ?-/2, :-/1, :-/2 and |/2 (they are operators the clause reader and the directive
# runner consume, not predicates) while ,/2 ;/2 ->/2 carry sixteen properties and call/1, findall/3 seventeen; SCRIP answered built_in and defined for the five. CURED in the run-time branch of
# predicate_property (by_name_dispatch.c) and the compile-time one (lower_prolog.c, a constant head): in the SWI dialect those three names are not built-ins. The GNU/ISO branch is untouched.
# The witness asks with a constant head (the lowerer's road), with a head held in a variable (the run-time road), by findall of all properties and by test, and keeps controls (atom_length, call,
# findall are built_in; append is defined; a user predicate is defined and static). The ref was cut from swipl 9.0.4 and swipl 10.1.5 reads it byte-identically.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/pps-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/pps.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
props(G) :- findall(P, predicate_property(G, P), Ps), length(Ps, N), ( N > 0 -> msort(Ps, S) ; S = none ), print(S), nl.
t(G) :- ( catch(findall(P, predicate_property(G, P), Ps), E, Ps = ex(E)) -> true ; Ps = failed ), length(Ps, N), ( N > 0 -> S = defined(N) ; S = none ), copy_term(G, G2), numbervars(G2, 0, _), print(G2-S), nl.
main :- props(?-(_,_)), props(?-(_)), props(:-(_,_)), props(:-(_)), props('|'(_,_)), props(foo_undefined(_)), props(zzz:foo(_)),
        t(?-(_,_)), t(?-(_)), t(:-(_,_)), t(:-(_)), t('|'(_,_)), t(foo_undefined(_)), t('$foo'(_)), t(zzz:foo(_)),
        ( predicate_property(atom_length(_,_), built_in) -> print(atom_length_builtin) ; print(atom_length_not) ), nl,
        ( predicate_property(call(_), built_in) -> print(call_builtin) ; print(call_not) ), nl,
        ( predicate_property(findall(_,_,_), built_in) -> print(findall_builtin) ; print(findall_not) ), nl,
        ( predicate_property(append(_,_,_), defined) -> print(append_defined) ; print(append_not) ), nl,
        ( predicate_property(main, defined) -> print(main_defined) ; print(main_not) ), nl,
        ( predicate_property(main, static) -> print(main_static) ; print(main_not_static) ), nl.
PL
cat > "$T/pps.ref" <<'REF'
none
none
none
none
none
none
none
?-(A,B)-none
(?-A)-none
(A:-B)-none
(:-A)-none
(A|B)-none
foo_undefined(A)-none
'$foo'(A)-none
(zzz:foo(A))-none
atom_length_builtin
call_builtin
findall_builtin
append_defined
main_defined
main_static
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/pps.pl" "$T/pps.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes report no property for the directive and bar names, as swipl does"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- predicate_property reports a property for ?-, :- or | where swipl reports none"; exit 1;; esac
