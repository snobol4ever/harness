:- use_module(library(pce)).
:- initialization(main, main).
churn(0) :- !.
churn(N) :- length(L, 50), atom_length(abc, _), L = [N|_], N1 is N-1, churn(N1).
keep(T) :- copy_term(T, T2), numbervars(T2, 0, _), print(kept(T2)), nl.
main :-
    new(C, chain),
    send(C, append, prolog(f(a, "str", [1,2,3], g(X, Y, X)))),
    X = bound_later, churn(200000),
    get(C, head, T), copy_term(T, T2), numbervars(T2, 0, _), print(T2), nl,
    ( var(Y) -> write(y_unbound) ; write(y_bound) ), nl,
    new(M, message(@prolog, keep, prolog(h(1.5, 'an atom', k(K))))),
    K = 9, churn(200000),
    send(M, execute), send(M, execute),
    send(C, clear), churn(200000),
    get(C, size, S), write(size(S)), nl,
    free(M), free(C), churn(200000), write(done), nl.
