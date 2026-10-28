:- initialization(main).
churn(0) :- !.
churn(N) :- T = f(N, g(N), [N,N]), arg(1, T, _), N1 is N - 1, churn(N1).
main :- b_setval(v, h(X, 7, Y)), churn(70), b_getval(v, T), T = h(P, Q, R), P = left, R = right, write(T-Q), nl,
        ( X == left -> write(shared) ; write(distinct) ), nl, churn(30), ( Y == right -> write(shared) ; write(distinct) ), nl.
