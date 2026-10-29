:- table p/1, r/1.
p(1).
p(X) :- p(Y), s(Y, X).
s(Y, X) :- r(Y), X is Y + 1, X < 6.
r(Y) :- p(Z), Z =< Y.
:- initialization((findall(X, p(X), L), msort(L, S), write(S), nl)).
