:- use_module(library(pce)).
:- initialization(main, main).
:- pce_begin_class(thrower, object).
boom(_Self) :-> throw(method_ball).
val(_Self, V:int) :<- throw(get_ball), V = 1.
multi(_Self) :-> member(X, [1,2,3]), write(m(X)), nl.
bind(_Self, T:prolog) :-> T = f(3).
twice(_Self, N:int, V:int) :<- V is N * 2.
:- pce_end_class.
show(V) :- ( var(V) -> write(unbound) ; write(V) ).
t(N, G) :- write(N), write(': '), ( catch(G, E, (write(caught(E)), nl)) -> write(yes) ; write(no) ), nl.
main :-
    new(O, thrower),
    t(1, send(O, boom)),
    new(M2, message(O, boom)), t(2, send(M2, execute)),
    t(3, get(O, val, _)),
    new(F, ?(O, val)), t(4, get(F, execute, _)),
    t(5, (send(O, multi), fail)),
    t(6, send(O, bind, prolog(Y))), show(Y), nl,
    new(M, message(O, bind, prolog(Z))), t(7, send(M, execute)), show(Z), nl,
    t(8, get(O, twice, 21, R)), show(R), nl,
    new(F2, ?(O, twice, 4)), t(9, get(F2, execute, R2)), show(R2), nl.
