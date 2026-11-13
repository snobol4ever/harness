:- initialization(main).
:- dynamic d/1.
s(X, Y) :- Y is X * 2.
t(G) :- catch(( call(G) -> R = yes ; R = no ), error(E, _), ( E = existence_error(_, _) -> R = existence ; E = type_error(_, _) -> R = type ; R = other )), write(R), nl.
main :- call(s, 3, A), write(A), nl,
        G = s(4), call(G, B), write(B), nl,
        call(( s(1, C), C > 1 )), write(C), nl,
        t(d(_)), assertz(d(1)), t(d(_)), retract(d(1)), t(d(_)),
        t(nosuch(1)), t(3),
        assertz(e(7)), t(e(7)), retract(e(7)), t(e(7)),
        findall(X, call(member, X, [a, b]), L), write(L), nl,
        ( call(( fail ; true )) -> write(alt) ; write(noalt) ), nl,
        call(call, s, 5, D), write(D), nl,
        ( call(( member(Y, [1, 2, 3]), Y > 1, ! )) -> write(Y) ; write(none) ), nl.
