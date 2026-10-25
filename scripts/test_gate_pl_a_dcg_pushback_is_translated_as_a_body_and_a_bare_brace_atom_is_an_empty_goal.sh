#!/bin/bash
# test_gate_pl_a_dcg_pushback_is_translated_as_a_body_and_a_bare_brace_atom_is_an_empty_goal.sh
# -- THE DCG PUSHBACK (ceo CEO-1959; row prolog-swi-core-test-read-every-case-agrees-with-swipl-in-both-modes-ceo-1664 and the umbrella prolog-swi-to-100-the-failing-cases-ceo-1930, SWI
# core/test_dcg.pl context:generalcontext and context:epsilonness). A rule `Head, Pushback --> Body` is translated Head(S0, S) :- Body from S0 to S1, Pushback from S to S1 -- the pushback is
# an ordinary DCG body run from the final state to the middle state, so it may be terminals, a non-terminal (b, d --> [].), the empty goal {} or a mix. SCRIP's consulted-rule translator
# handled a terminal list only: a non-terminal pushback unified S with the wrong term, and a bare {} body was called as the non-terminal {}/2. expand_term/2's translator already did the
# first and now reads {} as the empty goal too. The program is the witness (the suite's own rules plus a terminal-list, a non-terminal, a {} and a {}-with-terminals pushback) and its ref was
# cut from swipl 10.1.5 (/home/resources/swipl-mon/bin/swipl); swipl 9.0.4 prints the same lines.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/pbw-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/pbw.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
a, [_] --> !, {fail}.
a --> [_].
b, d --> [].
d --> [ce,ci].
e --> [].
e,({},[]) --> [].
e,{},[] --> [].
e,{},([],{},[]) --> [].
e,({},[]),{},[] --> [].
e,[],[],[],[] --> [].
e --> b,d.
e,[] --> b,[ce,ci].
e,[] --> b,b,[ce,ci,ce,ci].
e --> b,b,[ce,ci,ce,ci].
e --> b,b,d,b,d,b,b,b,d,d,d,d.
h, [p,q] --> [x].
i, d --> [x].
j, {} --> [x].
k, ({}, [m]) --> [x].
l, [r] --> {}, [x].
show(G) :- ( \+ \+ ( call(G), numbervars(G, 0, _), print(G), nl ) -> true ; print(failed(G)), nl ).
main :-
    ( phrase(a, [quidquid], []) -> writeln(a_yes) ; writeln(a_no) ),
    show(phrase(b, _, _)),
    ( setof(X, phrase(e, X), Xs) -> print(Xs), nl ; writeln(e_failed) ),
    findall(X1, phrase(e, X1), L1), length(L1, N1), print(N1), nl,
    show(phrase(h, _, _)),
    show(phrase(i, _, _)),
    show(phrase(j, _, _)),
    show(phrase(k, _, _)),
    show(phrase(l, _, _)),
    show(phrase(h, [x,1], _)),
    ( phrase(h, [x|T], [p,q|T]) -> writeln(h_roundtrip) ; writeln(h_no) ).
PL
cat > "$T/pbw.ref" <<'REF'
a_no
phrase(b,A,[ce,ci|A])
[[]]
11
phrase(h,[x|A],[p,q|A])
phrase(i,[x|A],[ce,ci|A])
phrase(j,[x|A],A)
phrase(k,[x|A],[m|A])
phrase(l,[x|A],[r|A])
phrase(h,[x,1],[p,q,1])
h_roundtrip
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/pbw.pl" "$T/pbw.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes translate a DCG pushback as a body and read a bare {} as an empty goal, as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a DCG pushback or a bare {} body does not answer as swipl"; exit 1;; esac
