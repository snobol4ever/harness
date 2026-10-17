#!/usr/bin/env bash
# test_gate_pl_consult_loads_a_file_of_clauses_directives_and_initialization_goals.sh -- consult/1 AT RUN TIME (ceo CEO-1522).
# SCRIP had no consult/1 for a file named at run time (the driver inlines only a literal consult at compile time), so the Logtalk adapter's
# '$lgt_load_prolog_code'(File, _, _) :- consult(File) raised existence_error(procedure, consult/1) after Logtalk compiled its first entity.
# consult/1 lives in the prelude: it resolves F or F.pl, reads every term, runs a directive (multifile and discontiguous accepted), adds a clause,
# and runs the file's initialization goals after the load. The witness file is written the way Logtalk writes its generated code -- canonical
# clauses and directives in functional notation, ':-(H, B)' and ':-(dynamic(...))' -- and consulted through a variable; swipl's text, both modes.
# RED BEFORE on origin 32a7c941d (existence_error on consult/1).
set -u
GATE_NAME=test_gate_pl_consult_loads_a_file_of_clauses_directives_and_initialization_goals
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_pl_witness_gate.sh"
printf ':-(dynamic(/(d,1))).\n:-(multifile(/(m,1))).\nd(1).\n:-(h(X), d(X)).\n:-(discontiguous(/(z,1))).\n:- initialization((write(init_ran), nl)).\n' > "$PLW_TMP/gen.txt"
cat > "$PLW_TMP/con.pl" <<'PL'
:- initialization(main).
main :- F = 'gen.txt', consult(F), h(X), write(X), nl, ( catch(consult(no_such_file_here), error(E, _), (write(E), nl)) -> true ; true ).
PL
pl_witness "consult of a generated file" con.pl "$(printf 'init_ran\n1\nexistence_error(source_sink,no_such_file_here)')"
pl_witness_end "consult/1 loads canonical clauses and directives, runs the file's initialization goal and refuses a missing file, in both modes"
