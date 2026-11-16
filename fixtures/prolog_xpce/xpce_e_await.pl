:- use_module(library(pce)).
:- initialization(main, main).
:- dynamic n/1, slept/0.
n(0).
tick :- retract(n(N)), N1 is N+1, assert(n(N1)),
    ( slept -> write(tick(N1)), nl, flush_output, ( N1 =:= 3 -> halt ; true )
    ; assert(n(early)) ).
main :-
    new(T, timer(0.2, message(@prolog, tick))), send(T, start),
    sleep(1),
    ( n(early) -> write(ticked_in_sleep) ; write(no_tick_in_sleep) ), nl, flush_output,
    assert(slept),
    read(_),
    write(read_returned), nl.
