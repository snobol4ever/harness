:- initialization(main).
p(X, Y) :- Y is X + 1.
loop(0, A, A) :- !.
loop(N, A0, A) :- G = p(N), call(G, V), A1 is A0 + V, N1 is N - 1, loop(N1, A1, A).
main :- loop(200000, 0, A), write(A), nl.
