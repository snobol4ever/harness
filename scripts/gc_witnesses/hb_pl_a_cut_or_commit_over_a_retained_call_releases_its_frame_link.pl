p(X) :- member(X, [a,b,c]).
g(N) :- numlist(1, N, L), msort(L, _).
t1 :- ( p(X), X == b -> write(found(X)) ; write(none) ), nl, g(200).
t2 :- once(p(X)), write(X), nl, g(200).
t3 :- p(X), X == b, !, write(X), nl, g(200).
:- initialization((t1, t2, t3)).
