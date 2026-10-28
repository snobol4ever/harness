:- initialization(main).
churn(0) :- !.
churn(N) :- T = f(N, g(N), [N,N]), arg(1, T, _), N1 is N - 1, churn(N1).
main :- dif(X, a), churn(60), ( X = a -> write(unified) ; write(blocked) ), nl, churn(40), X = b, write(ok), nl.
