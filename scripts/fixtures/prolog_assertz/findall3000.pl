:- initialization(main).
:- dynamic f/1.
gen(0) :- !.
gen(N) :- assertz(f(N)), M is N - 1, gen(M).
main :- gen(3000), findall(X, f(X), L), length(L, Len), write(Len), nl.
