:- initialization(main).
churn(0) :- !.
churn(N) :- T = f(N, g(N), [N,N]), arg(1, T, _), N1 is N - 1, churn(N1).
main :- engine_create(f(X, Y, Z), member(X-Y-Z, [1-a-p, 2-b-q, 3-c-r]), E),
        engine_next(E, T1), churn(70), engine_next(E, T2), churn(40), engine_next(E, T3), write(T1), nl, write(T2), nl, write(T3), nl,
        ( engine_next(E, _) -> write(more) ; write(done) ), nl.
