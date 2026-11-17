% L34: library(prolog_colour) colours the options of a call whose predicate declares them (open/4, write_term/3), and an option the declaration lacks; the colourer reads the declarations through library(predicate_options) (DESIGN J20).
:- use_module(library(prolog_colour)).
:- initialization(main, main).
:- dynamic frag/3.
collect(C, S, L) :- assertz(frag(C, S, L)).
main :-
    open_string("t :- open(f, read, S, [type(binary), bogus(1)]), write_term(S, x, [quoted(true)]).\n", S),
    prolog_colourise_term(S, user, collect, []), close(S),
    forall(frag(C, St, L), ( numbervars(C, 0, _), print(St-L-C), nl )).
