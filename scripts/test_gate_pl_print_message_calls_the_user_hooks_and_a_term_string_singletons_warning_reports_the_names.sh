#!/bin/bash
# test_gate_pl_print_message_calls_the_user_hooks_and_a_term_string_singletons_warning_reports_the_names.sh
# -- THE MESSAGE HOOKS AND THE SINGLETONS WARNING (ceo CEO-1959; row prolog-swi-core-test-read-every-case-agrees-with-swipl-in-both-modes-ceo-1664, SWI core/test_read.pl
# read_term:warn_singletons). Three gaps, one witness built on the suite's own catch_messages helper. (1) print_message/2 ignored user:thread_message_hook/3 and message_hook/3; it now
# calls the first and then the second with the message term, its kind and its translated lines, and a hook that succeeds stops the default print. (2) asserta/assertz of a clause whose
# head is module-qualified -- (user:H :- B), with or without a clause reference -- raised permission_error(modify, static_procedure, (:)/2); the head is now unqualified before the
# predicate key is taken. (3) term_string/3 with singletons(warning) reported nothing and failed to unify the option; it now prints singletons(Term, Names) at kind warning for the named
# singletons (an underscore followed by an uppercase letter, a digit or an underscore is deliberately quiet, '_a' is not). The program is the witness and its ref was cut from swipl 10.1.5
# (/home/resources/swipl-mon/bin/swipl); swipl 9.0.4 prints the same lines.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/msgw-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/msgw.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
:- dynamic message/1.
:- dynamic qh/1.
:- meta_predicate catch_messages(?, 0, -).
catch_messages(Kind, Goal, Messages) :-
    setup_call_cleanup(
        asserta((user:thread_message_hook(Term, Kind, _) :-
                    \+ \+ ( prolog_load_context(variable_names, VarNames),
                            bind_variable_names(VarNames),
                            assertz(message(Term)))), Ref),
        once(Goal),
        erase(Ref)),
    findall(Msg, retract(message(Msg)), Messages).
bind_variable_names([]).
bind_variable_names([Name='$VAR'(Name)|T]) :- !, bind_variable_names(T).
bind_variable_names([_|T]) :- bind_variable_names(T).
show(M) :- \+ \+ ( numbervars(M, 0, _), print(M), nl ).
main :-
    assertz((user:qh(1) :- true)), assertz((user:qh(2) :- X2 = 2, X2 > 1)), assertz(user:qh(3)), asserta((user:qh(0) :- fail), R0), erase(R0),
    findall(Y, qh(Y), L0), print(L0), nl,
    catch_messages(_, term_string(_, "a(_,_a,_A,_0,A)", [singletons(warning)]), M1), show(M1),
    catch_messages(_, term_string(_, "f(X,Y,X)", [singletons(warning)]), M2), show(M2),
    catch_messages(_, term_string(_, "g(_A,_B,_)", [singletons(warning)]), M3), show(M3),
    catch_messages(_, term_string(_, "h(a)", [singletons(warning)]), M4), show(M4),
    catch_messages(_, print_message(informational, hello(world)), M5), show(M5),
    catch_messages(warning, print_message(informational, hello(again)), M6), show(M6),
    catch_messages(warning, print_message(warning, hello(again)), M7), show(M7),
    catch_messages(_, term_string(_, "k(_x,_y)", [singletons(warning)]), M8), show(M8).
PL
cat > "$T/msgw.ref" <<'REF'
[1,2,3]
[singletons(a(A,B,C,D,E),['_a','A'])]
[singletons(f(A,B,A),['Y'])]
[]
[]
[hello(world)]
[]
[hello(again)]
[singletons(k(A,B),['_x','_y'])]
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/msgw.pl" "$T/msgw.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes call the message hooks, assert a qualified-head clause and report the singletons warning, as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- the message hooks, the qualified-head assert or the singletons warning do not answer as swipl"; exit 1;; esac
