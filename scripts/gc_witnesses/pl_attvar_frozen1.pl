:- initialization(main).
churn(0) :- !.
churn(N) :- T = f(N, g(N), [N,N]), arg(1, T, _), N1 is N - 1, churn(N1).
main :- freeze(X, true), freeze(Y, true), put_attr(Z, k, 7), churn(70), ( frozen(X, G) -> ( G == true -> write(nogoal) ; write(hasgoal) ) ; write(nofrozen) ), nl,
        get_attr(Z, k, V), write(V), nl, term_attvars(f(X,Y,Z), Vs), length(Vs, L), write(L), nl.
