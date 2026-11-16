% L27: library(broadcast) with no window, as PceDraw and the demo menu reach it (listen/3 as a directive, broadcast/1, broadcast_request/1),
% and the input-context pair lib/pce_config.pl runs at lines 426 and 431.
:- use_module(library(broadcast)).
:- initialization(main, main).
:- dynamic seen/1.
:- listen(boot, hello(W), ( write(hello(W)), nl )).
main :-
    broadcast(hello(world)),
    listen(me, set_config(K, V), assertz(seen(K-V))),
    listen(me, config(size, X), X = 3),
    broadcast(set_config(colour, red)), broadcast(set_config(size, 3)),
    findall(P, seen(P), L), print(L), nl,
    ( broadcast_request(config(size, A)) -> print(answer(A)) ; print(no_answer) ), nl,
    ( broadcast_request(nobody(_)) -> print(answered) ; print(unanswered) ), nl,
    findall(t, listening(me, _, _), Ts), length(Ts, N1), print(listening(N1)), nl,
    unlisten(me), findall(t, listening(me, _, _), T2), length(T2, N2), print(listening(N2)), nl,
    '$push_input_context'(witness), '$pop_input_context', print(context_ok), nl.
