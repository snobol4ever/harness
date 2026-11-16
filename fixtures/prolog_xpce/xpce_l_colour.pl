% L28a: library(prolog_colour) with no window, as PceEmacs colours its first buffer: one clause coloured to its list of fragments.
:- use_module(library(prolog_colour)).
:- initialization(main, main).
:- dynamic frag/3.
collect(C, S, L) :- assertz(frag(C, S, L)).
main :-
    open_string("foo(X, \"s\") :- bar(X), !, baz([1,2|_]), Y = 'q a', format(\"~w~n\", [Y]).\n", S),
    prolog_colourise_term(S, user, collect, []), close(S),
    forall(frag(C, St, L), ( numbervars(C, 0, _), print(St-L-C), nl )).
