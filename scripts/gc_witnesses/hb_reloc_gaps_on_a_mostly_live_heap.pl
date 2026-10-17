myapp([], L, L).
myapp([H|T], L, [H|R]) :- myapp(T, L, R).
nrev([], []).
nrev([H|T], R) :- nrev(T, RT), myapp(RT, [H], R).
:- initialization(main).
main :- findall(X, between(1,30,X), L), nrev(L, R), write(R), nl.
