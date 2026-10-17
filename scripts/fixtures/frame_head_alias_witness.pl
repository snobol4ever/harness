p(X) :- ( X = 1 ; X = 2 ), write(X), nl, fail.
p(_).
t(X, X).
u(_, _).
v(f(X), X).
w(X, Y, X) :- write(Y), nl.
s(X) :- X = 7.
r(N) :- N > 0, N1 is N - 1, r(N1).
r(0).
k(X) :- integer(X), X > 0.
k(f(X)) :- X = z.
m(X) :- integer(X).
m(f(X)) :- m(X), write(X), nl.
b(X) :- c(X).
b3(X) :- true, c(X).
b4(X, Y) :- c(X), c(Y).
c(X) :- X = 5.
:- initialization(main).
main :- p(_), ( var(Q), p(Q) -> true ; true ), ( t(a, a) -> write(t_ok) ; write(t_bad) ), nl, ( t(a, b) -> write(t2_bad) ; write(t2_ok) ), nl, ( u(a, b) -> write(u_ok) ; write(u_bad) ), nl, ( v(f(c), c) -> write(v_ok) ; write(v_bad) ), nl, ( v(f(c), d) -> write(v2_bad) ; write(v2_ok) ), nl, w(1, 2, 1), ( w(1, 2, 3) -> write(w_bad) ; write(w_ok) ), nl, s(Z), write(Z), nl, ( s(8) -> write(s2_bad) ; write(s2_ok) ), nl, r(5), write(r_ok), nl, ( k(3) -> write(k_ok) ; write(k_bad) ), nl, ( k(f(z)) -> write(k2_ok) ; write(k2_bad) ), nl, ( k(f(y)) -> write(k3_bad) ; write(k3_ok) ), nl, m(f(f(f(1)))), b(B), write(b(B)), nl, b3(B3), write(b3(B3)), nl, b4(P4, Q4), write(b4(P4, Q4)), nl.
