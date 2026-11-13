:- initialization(main).
:- dynamic f/2, g/2.
main :- assertz(f(1, a)), assertz(f(2, b)), assertz(f(1, c)), assertz(g(X, X)), assertz(g(p, q)),
        findall(V, f(1, V), L1), write(L1), nl,
        findall(K, f(K, b), L2), write(L2), nl,
        ( g(z, W) -> write(W) ; write(none) ), nl,
        findall(A-B, g(A, B), L3), length(L3, N3), write(N3), nl,
        ( f(_, V2), assertz(f(9, V2)), fail ; true ), findall(K2, f(K2, _), L4), write(L4), nl,
        ( f(K3, _), retract(f(K3, _)), fail ; true ), ( f(_, _) -> write(left) ; write(empty) ), nl,
        freeze(Y, ( write(woke), nl )), assertz(f(5, five)), f(Y, five), write(Y), nl.
