:- initialization(main).
:- dynamic g/2.
loop(0, S, S) :- !.
loop(N, S0, S) :- g(S0, S1), N1 is N - 1, loop(N1, S1, S).
main :- assertz((g(X, Y) :- Y is X + 1)), loop(300000, 0, S), write(S), nl.
