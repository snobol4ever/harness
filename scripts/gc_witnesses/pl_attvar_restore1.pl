:- initialization(main).
churn(0) :- !.
churn(N) :- T = f(N, g(N), [N,N]), arg(1, T, _), N1 is N - 1, churn(N1).
main :- put_attr(X, m, one), ( put_attr(X, m, two), churn(80), get_attr(X, m, A), write(in(A)), nl, fail ; true ),
        churn(40), get_attr(X, m, B), write(after(B)), nl,
        ( member(Z, [1,2,3]), freeze(Q, (write(wake(Q)), nl)), churn(30), Q = Z, fail ; true ), write(end), nl.
