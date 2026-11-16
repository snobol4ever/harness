:- use_module(library(pce)).
:- initialization(main, main).
:- dynamic n/1.
n(0).
tock :- retract(n(N)), N1 is N+1, assert(n(N1)), write(tock(N1)), nl, ( N1 =:= 3 -> throw(tock_ball) ; true ).
main :-
    new(T, timer(0.1, message(@prolog, tock))), send(T, start),
    catch(loop(100), E, (write(caught(E)), nl)),
    send(T, stop),
    n(K), write(tocks(K)), nl.
loop(0) :- !.
loop(N) :- pce_dispatch, N1 is N-1, loop(N1).
