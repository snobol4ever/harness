% L26: library(unicode/blocks) with no window, as FontViewer calls it (fill_chart_menu/1: every block's name, then one block's range by its name).
:- use_module(library(unicode/blocks)).
:- initialization(main, main).
block_of(C, N) :- unicode_block(N, F, T), F =< C, C =< T, !.
main :-
    forall(member(C, [0x41, 0x3B1, 0x4E2D]), ( block_of(C, N), format("~16r ~w~n", [C, N]) )),
    findall(N, unicode_block(N, _, _), Ns), length(Ns, K), format("blocks ~d~n", [K]),
    unicode_block('Greek and Coptic', F, T), format("~16r ~16r~n", [F, T]),
    ( unicode_block(no_such_block, _, _) -> writeln(found) ; writeln(none) ).
