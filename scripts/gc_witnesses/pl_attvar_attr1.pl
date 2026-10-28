:- initialization(main).
churn(0) :- !.
churn(N) :- T = f(N, g(N), [N,N]), arg(1, T, _), N1 is N - 1, churn(N1).
main :- put_attr(X, m, v1), churn(60), put_attr(X, m, v2), churn(60), get_attr(X, m, V), write(V), nl,
        put_attr(Y, n, a), churn(40), ( get_attr(Y, m, _) -> write(wrong) ; write(none_m) ), nl, get_attr(Y, n, W), write(W), nl.
