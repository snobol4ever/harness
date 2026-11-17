% L27: the input-context pair lib/pce_config.pl, library(prolog_source) and library(prolog_xref) call around a nested read:
% '$push_input_context'(Type) saves the current input, '$pop_input_context' restores it, and a pop with nothing pushed fails.
:- initialization(main, main).
same(S) :- current_input(C), ( C == S -> print(same) ; print(moved) ), nl.
main :-
    current_input(U),
    open_string("outer(1). outer(2).", S1), open_string("inner(a).", S2),
    '$push_input_context'(outer),
    set_input(S1), read(T1), print(T1), nl,
    '$push_input_context'(inner),
    set_input(S2), read(T2), print(T2), nl, same(S2),
    '$pop_input_context', same(S1),
    read(T3), print(T3), nl,
    '$pop_input_context', same(U),
    ( '$pop_input_context' -> print(popped) ; print(empty) ), nl, same(U),
    catch('$push_input_context'(_), error(E1, _), (print(E1), nl)),
    catch('$push_input_context'(f(x)), error(E2, _), (print(E2), nl)),
    close(S1), close(S2).
