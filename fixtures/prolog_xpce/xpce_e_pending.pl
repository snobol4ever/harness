:- use_module(library(pce)).
:- initialization(main, main).
boom :- throw(my_ball).
boom2 :- throw(second_ball).
val(V) :- V = 7.
badval(_) :- throw(get_ball).
t(N, G) :- write(N), write(': '), ( catch(G, E, (write(caught(E)), nl)) -> write(yes) ; write(no) ), nl.
main :-
    new(A, and(message(@prolog, boom), message(@prolog, boom2))), t(1, send(A, execute)),
    new(A2, and(message(@prolog, true), message(@prolog, boom2))), t(2, send(A2, execute)),
    new(O2, or(message(@prolog, boom), message(@prolog, boom2))), t(3, send(O2, execute)),
    t(4, (get(@prolog, val, V), write(V), nl)),
    t(5, get(@prolog, badval, _)),
    new(F, ?(@prolog, val)), t(6, (get(F, execute, V2), write(V2), nl)),
    new(F2, ?(@prolog, badval)), t(7, get(F2, execute, _)).
