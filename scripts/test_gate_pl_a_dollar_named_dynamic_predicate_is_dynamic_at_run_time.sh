#!/usr/bin/env bash
# test_gate_pl_a_dollar_named_dynamic_predicate_is_dynamic_at_run_time.sh -- A PREDICATE NAMED WITH A LEADING $ IS A USER PREDICATE (ceo CEO-1522).
# pl_db_decls_capture skipped every dynamic predicate whose name starts with $, taking it for SCRIP's own, so a user's ':- dynamic('$c_'/2).'
# never reached the run-time registry: an assertz through the term road, a predicate_property and a retractall each saw a "static" predicate,
# and the Logtalk runtime ('$lgt_send_to_obj_'/3 and its cache family) raised permission_error(modify, static_procedure) at its first cache
# reset. Only SCRIP's own names are hidden now (the prelude's definitions and '$pl_cconv'/2). The witness is Logtalk's shape: a declared
# dynamic predicate with a catch-all file clause, a cached clause asserted through the term road, a reset through an if-then-else chain
# that retracts every clause and re-asserts the catch-all; swipl's text, both modes. RED BEFORE on origin 32a7c941d.
set -u
GATE_NAME=test_gate_pl_a_dollar_named_dynamic_predicate_is_dynamic_at_run_time
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_pl_witness_gate.sh"
cat > "$PLW_TMP/dol.pl" <<'PL'
:- dynamic('$c_'/2).
'$c_'(X, Y) :- '$c_nv'(X, Y).
'$c_nv'(X, Y) :- Y = computed(X), asserta(('$c_'(X, Y) :- !)).
clean :- ( flag_off -> clean_u ; clean_u ).
flag_off :- fail.
clean_u :- retractall('$c_'(_, _)), reassert.
reassert :- assertz(('$c_'(X, Y) :- '$c_nv'(X, Y))).
:- initialization(main).
main :- '$c_'(a, A), write(A), nl, ( predicate_property('$c_'(_, _), dynamic) -> write(dynamic) ; write(static) ), nl, clean, '$c_'(b, B), write(B), nl, aggregate_all(count, clause('$c_'(_, _), _), N), write(N), nl.
PL
pl_witness "dollar-named dynamic predicate" dol.pl "$(printf 'computed(a)\ndynamic\ncomputed(b)\n2')"
pl_witness_end "a \$-named dynamic predicate is dynamic at run time in both modes: cached through the term road, reset by retractall, re-asserted"
