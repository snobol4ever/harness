%  WITNESS for HB_PSEG (233) -- a parked tabling segment (the stack bytes and trail records of a suspended consumer), held across allocation churn, then read back.
:- initialization(main).
:- table path/2.
edge(1, 2).
edge(2, 3).
edge(3, 4).
edge(4, 1).
edge(4, 5).
churn(0) :- !.
churn(N) :- findall(X-Y, (between(1, 30, X), Y = f(X, X)), _), M is N - 1, churn(M).
path(X, Y) :- edge(X, Y).
path(X, Y) :- path(X, Z), churn(40), edge(Z, Y).
main :- findall(Y, path(1, Y), L), sort(L, S), length(S, C), write('PSEG-'), write(C), nl.
