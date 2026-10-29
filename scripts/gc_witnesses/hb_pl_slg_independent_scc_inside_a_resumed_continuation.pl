:- table p/1, t/1.
p(1).
p(X) :- p(Y), s(Y, X).
s(Y, X) :- t(Y), X is Y + 1, X < 6.
t(Y) :- t(Z), Z < 3, Y is Z + 1.
t(0).
:- initialization((findall(X, p(X), L), msort(L, S), write(S), nl)).
