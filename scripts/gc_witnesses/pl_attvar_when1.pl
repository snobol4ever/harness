:- initialization(main).
churn(0) :- !.
churn(N) :- T = f(N, g(N), [N,N]), arg(1, T, _), N1 is N - 1, churn(N1).
main :- when(ground(X+Y), (write(go(X,Y)), nl)), churn(60), X = 1, churn(60), write(mid), nl, Y = 2, write(done), nl.
