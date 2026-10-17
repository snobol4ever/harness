chain(0) :- !.
chain(N) :- between(1, 2, _), N1 is N - 1, chain(N1).
g(N) :- numlist(1, N, L), msort(L, S), length(S, Len), write(Len), nl.
:- initialization((chain(200), g(3000), g(3000), !, write(done), nl)).
