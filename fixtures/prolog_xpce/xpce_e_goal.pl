:- use_module(library(pce)).
:- initialization(main, main).
boom :- throw(my_ball).
gen :- member(X, [1,2,3]), write(g(X)), nl.
nest :- new(P, point(5,6)), get(P, x, X), write(nested(X)), nl, send(@prolog, inner).
inner :- throw(inner_ball).
bindit(X) :- X = g(4).
show(V) :- ( var(V) -> write(unbound) ; write(V) ).
t(N, G) :- write(N), write(': '), ( catch(G, E, (write(caught(E)), nl)) -> write(yes) ; write(no) ), nl.
main :-
    t(1, send(@prolog, boom)),
    new(M, message(@prolog, boom)), t(2, send(M, execute)),
    t(3, (send(@prolog, gen), fail)),
    t(4, send(@prolog, nest)),
    new(M3, message(@prolog, nest)), t(5, send(M3, execute)),
    t(6, send(@prolog, bindit, V)), show(V), nl,
    new(M2, message(@prolog, bindit, prolog(W))), t(7, send(M2, execute)), show(W), nl,
    t(8, send(@prolog, bindit, prolog(X))), show(X), nl.
