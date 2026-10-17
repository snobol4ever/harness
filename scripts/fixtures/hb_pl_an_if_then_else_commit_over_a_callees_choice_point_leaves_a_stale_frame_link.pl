noop(_).
run(10, pplus(A, B, C)) :- ( noop(x), B is C - A ; true ).
try(N) :- ( run(N, pplus(4, Y, 9)) -> write(N-bound(Y)) ; write(N-failed) ), nl.
main :- try(10), halt.
:- initialization(main).
