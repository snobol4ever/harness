:- initialization(main).
q(X, f(X)).
r(X, X).
t(N, G) :- ( catch(G, error(occurs_check(_, _), _), (write(N-raised), nl, fail)) -> write(N-yes) ; write(N-no) ), nl.
loop(0) :- !.
loop(K) :- t(1, X1 = f(X1)), t(2, f(X2, Y2) = f(Y2, g(X2))), t(3, q(A3, A3)), t(4, r(A4, g(A4))), t(5, (X5 = Y5, Y5 = h(X5))), t(6, \+ X6 = f(X6)), t(7, X7 = [a|X7]), t(8, f(a) = f(b)), K1 is K - 1, loop(K1).
main :- set_prolog_flag(occurs_check, error), loop(3), set_prolog_flag(occurs_check, true), t(10, X10 = f(X10)), set_prolog_flag(occurs_check, false), t(11, f(a) = f(a)), halt.
