:- table a/1, b/1, c/1.
a(X) :- b(X).
a(1).
b(X) :- c(X).
b(2).
c(X) :- a(Y), X is Y + 1, X < 6.
c(3).
:- initialization((findall(X, a(X), L), msort(L, S), write(S), nl)).
