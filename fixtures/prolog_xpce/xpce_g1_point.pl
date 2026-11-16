% G1: the object protocol on non-graphical objects; no display needed; no integer reference is printed.
:- use_module(library(pce)).
:- initialization(main, main).
main :-
    new(P, point(1, 2)), get(P, x, X), get(P, y, Y), format("point ~w ~w~n", [X, Y]),
    send(P, x, 7), send(P, offset, 1, 1), get(P, x, X2), get(P, y, Y2), format("moved ~w ~w~n", [X2, Y2]),
    ( object(P) -> writeln(exists) ; writeln(gone) ),
    free(P), ( object(P) -> writeln(exists) ; writeln(gone) ),
    new(@p, point(3, 4)), get(@p, x, PX), format("named ~w ~w~n", [@p, PX]),
    get(@p, class_name, CN), format("class ~w~n", [CN]),
    new(C, chain(a, b, c)), send(C, append, d), get(C, size, N), chain_list(C, L), format("chain ~w ~w~n", [N, L]),
    get(C, head, H), get(C, tail, T), format("ends ~w ~w~n", [H, T]),
    ( send(C, member, b) -> writeln(member_b) ; writeln(no_b) ),
    ( send(C, member, z) -> writeln(member_z) ; writeln(no_z) ),
    new(S, string('hello %s %d', world, 42)), get(S, value, V), format("string ~w~n", [V]),
    get(S, size, SL), format("length ~w~n", [SL]),
    send(S, upcase), get(S, value, VU), format("upcase ~w~n", [VU]),
    ( catch(send(@p, no_such_method), E, (print_message(silent, E), fail)) -> writeln(sent) ; writeln(refused) ),
    free(@p), ( object(@p) -> writeln(exists) ; writeln(gone) ),
    halt.
