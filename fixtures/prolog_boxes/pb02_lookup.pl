:- initialization(main).
:- dynamic f/2.
fill(0) :- !.
fill(N) :- assertz(f(N, N)), N1 is N - 1, fill(N1).
look(0, A, A) :- !.
look(N, A0, A) :- K is N mod 2000 + 1, f(K, V), A1 is A0 + V, N1 is N - 1, look(N1, A1, A).
main :- fill(2000), look(400000, 0, A), write(A), nl.
