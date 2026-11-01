mk(0, []) :- !.
mk(N, [N|T]) :- M is N - 1, mk(M, T).
loop(0, T, U, _) :- !, write(T), nl, write(U), nl.
loop(N, T, U, _) :- M is N - 1, loop(M, T, U, _).
loop2(0, T, _, U) :- !, write(U), nl, length(T, L), write(L), nl.
loop2(N, T, _, U) :- M is N - 1, loop2(M, T, _, U).
t1 :- findall(X, between(1, 500, X), _), mk(8, T), U = f(g(T), str, 3.5, [a,b]), loop(200, T, U, _).
t2 :- findall(X, between(1, 500, X), _), mk(30, T), U = h(T, k), ( member(_, [1,2]), loop2(150, T, _, U), fail ; true ).
:- t1, t2, write(ok), nl.
