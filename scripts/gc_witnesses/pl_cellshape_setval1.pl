:- initialization(main).
churn(0) :- !.
churn(N) :- T = f(N, g(N), [N,N]), arg(1, T, _), N1 is N - 1, churn(N1).
main :- nb_setval(k, f(X, 1, 2)), churn(80), nb_getval(k, V), V = f(A, B, C), A = q, write(V-B-C), nl,
        X = free, churn(40), nb_getval(k, V2), write(V2), nl.
