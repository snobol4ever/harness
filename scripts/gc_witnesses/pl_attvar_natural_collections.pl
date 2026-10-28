:- initialization(main).
churn(0) :- !.
churn(N) :- atom_codes(A, "abcdefgh"), atom_length(A, _), T = f(N, N, g(N)), arg(1, T, _), N1 is N - 1, churn(N1).
main :- put_attr(X, m, val), freeze(Y, (write(woke), nl)), churn(20000),
        ( get_attr(X, m, V) -> write(attr(V)) ; write(attr_lost) ), nl,
        Y = 1, write(done), nl.
