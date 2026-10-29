:- table p/1, q/1.
p(X) :- q(X).
p(X) :- p(Y), Y < 4, X is Y + 1.
q(X) :- q(Y), Y < 3, X is Y + 1.
q(0).
:- initialization((findall(X, p(X), L), msort(L, S), write(S), nl)).
