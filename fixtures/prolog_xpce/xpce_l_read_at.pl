% L28c: library(prolog_source) with no window: a term read at a location, as PceEmacs's mode reads one (read_source_term_at_location/3).
:- use_module(library(prolog_source)).
:- initialization(main, main).
main :-
    forall(member(L, [5, 6, 2]), ( open('cmp_xref_subject.pl', read, S),
        ( read_source_term_at_location(S, T, [line(L), module(user)]) -> true ; T = none ), close(S), numbervars(T, 0, _), print(L-T), nl )).
