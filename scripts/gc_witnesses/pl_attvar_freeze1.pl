:- initialization(main).
churn(0) :- !.
churn(N) :- T = f(N, g(N), [N,N]), arg(1, T, _), N1 is N - 1, churn(N1).
main :- freeze(X, (write(woke(X)), nl)), freeze(X, (write(second), nl)), churn(60), write(before), nl, X = 1, write(done), nl.
