:- initialization(main).
churn(0) :- !.
churn(N) :- T = f(N, g(N), [N,N]), arg(1, T, _), N1 is N - 1, churn(N1).
main :- T = f(_), nb_setarg(1, T, g(_, keep, _)), churn(80), arg(1, T, G), G = g(A, K, B), A = one, B = two, write(G), nl, write(K), nl,
        churn(40), arg(1, T, G2), write(G2), nl.
