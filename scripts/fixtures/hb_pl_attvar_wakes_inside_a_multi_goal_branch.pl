m:attr_unify_hook(a, V) :- V \== 5.
noop(_).
kill(5).
run(1, pplus(A, B, C)) :- ( nonvar(C) -> noop(x), B is C - A ; true ).
run(2, pplus(A, B, C)) :- ( nonvar(C) -> B is C - A, noop(x) ; true ).
run(3, pplus(_, B, _)) :- ( true -> noop(x), B = 5 ; true ).
run(4, pplus(_, B, _)) :- ( true -> B = 5, noop(x) ; true ).
run(5, pplus(A, B, C)) :- ( true -> noop(x), B is C - A ; true ).
run(6, pplus(A, B, C)) :- plain(A, B, C).
run(7, pplus(_, B, _)) :- ( true -> noop(x), kill(B) ; true ).
run(8, pplus(A, B, C)) :- ( fail -> true ; noop(x), B is C - A ).
run(9, pplus(A, B, C)) :- ( noop(x), B is C - A -> write(then), write(' ') ; write(else), write(' ') ).
run(10, pplus(A, B, C)) :- ( noop(x), B is C - A ; true ).
run(11, pplus(A, B, C)) :- \+ ( noop(x), B is C - A ).
run(12, pplus(A, B, C)) :- ( nonvar(C) -> ( true -> noop(x), B is C - A ; true ) ; true ).
run(13, pplus(A, B, C)) :- ( nonvar(C) -> noop(x), B is C - A ).
run(14, pplus(A, B, C)) :- ( nonvar(C) *-> noop(x), B is C - A ; true ).
run(15, pplus(A, B, C)) :- findall(B, (noop(x), B is C - A), L), write(L), write(' ').
run(16, pplus(A, B, C)) :- forall((noop(x), B is C - A), true).
run(17, pplus(A, B, C)) :- ( nonvar(C) -> noop(x), B is C - A, noop(y) ; true ).
run(18, pplus(A, B, C)) :- ( nonvar(C) -> noop(x), noop(y), B is C - A ; true ).
run(19, pplus(A, B, C)) :- once((noop(x), B is C - A)).
run(20, pplus(A, B, C)) :- catch((noop(x), B is C - A), _, true).
run(21, pplus(_, B, C)) :- ( nonvar(C) -> noop(x), B = C ; true ).
run(22, pplus(A, B, C)) :- ( nonvar(C) -> noop(x), B is C - A, write(after), write(' ') ; true ).
run(23, pplus(A, B, C)) :- P = pplus(A, B, C), ( nonvar(C) -> noop(x), arg(2, P, B2), B2 is C - A ; true ).
run(24, pplus(A, B, C)) :- ( nonvar(C) -> noop(x), ( B is C - A ; true ) ; true ).
plain(A, B, C) :- ( nonvar(C) -> noop(x), B is C - A ; true ).
try(N) :- put_attr(Y, m, a), ( run(N, pplus(4, Y, 9)) -> write(N-bound(Y)) ; write(N-failed) ), nl.
main :- forall(between(1, 24, N), try(N)), halt.
:- initialization(main).
