:- initialization(main).
:- dynamic f/1.
gen(0) :- !.
gen(N) :- assertz(f(N)), M is N - 1, gen(M).
cnt(N) :- nb_setval(k, 0), ( f(_), nb_getval(k, K), K1 is K + 1, nb_setval(k, K1), fail ; nb_getval(k, N) ).
main :- gen(100), cnt(N), write(N), nl.
