#!/usr/bin/env bash
# test_gate_pl_the_neck_atom_before_an_adjacent_paren_is_functional_notation.sh -- ':-(H, B)' IS A TERM (ISO 6.3.3; ceo CEO-1522).
# An atom immediately followed by '(' is functional notation whatever the atom, but the parser read ':-(' as the prefix directive operator
# applied to a parenthesised comma term: in source 'X = :-(a, b)' was a priority clash, read_term gave ':-'/1 for ':-(p(1), true)', and a top-level
# ':-(head(1), true).' ran as a directive -- so a consult of Logtalk's generated code executed its clauses as goals. The neck and query tokens now
# take the adjacent-paren road the atom case already had; a top-level canonical clause is a clause and ':-(D).' a directive. swipl's text, both modes.
# RED BEFORE on origin 32a7c941d.
set -u
GATE_NAME=test_gate_pl_the_neck_atom_before_an_adjacent_paren_is_functional_notation
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_pl_witness_gate.sh"
printf ':-(p(1), true).\n' > "$PLW_TMP/canon.txt"
cat > "$PLW_TMP/fun.pl" <<'PL'
:-(head(1), true).
:-(dynamic(q/1)).
q(9).
:- initialization(main).
main :- X = :-(a, b), functor(X, N, A), writeq(N/A), nl,
        open('canon.txt', read, S), read_term(S, T, []), close(S), functor(T, N2, A2), writeq(N2/A2), nl,
        head(H), write(H), nl, assertz(q(10)), findall(Q, q(Q), L), write(L), nl.
PL
pl_witness "the neck in functional notation" fun.pl "$(printf '(:-)/2\n(:-)/2\n1\n[9,10]')"
pl_witness_end "':-(A, B)' is a two-argument term in source, through read_term, and as a top-level clause; ':-(D).' is a directive; both modes"
