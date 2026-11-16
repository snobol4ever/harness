:- use_module(library(pce)).
:- pce_begin_class(w_pair, object, "two numbers").
variable(a, int, both, "first").
variable(b, int, both, "second").
initialise(P, A:int, B:int) :->
    send_super(P, initialise),
    send(P, a, A),
    send(P, b, B).
sum(P, S:int) :<-
    get(P, a, A),
    get(P, b, B),
    S is A + B.
:- pce_end_class.
main :-
    forall(member(O, [@, ?, :=, :->, :<-]),
           ( current_op(Pr, T, O) -> writeq(op(O, Pr, T)), nl ; writeq(no_op(O)), nl )),
    current_prolog_flag(xpce_threaded, Th), writeq(xpce_threaded(Th)), nl,
    forall(member(H, [new(_, _), send(_, _), get(_, _, _), send(_, _, _)]),
           ( predicate_property(H, imported_from(M)) -> functor(H, N, A), writeq(N/A - M), nl ; true )),
    new(P, w_pair(3, 4)),
    get(P, sum, S), writeq(sum(S)), nl,
    send(P, free),
    writeln(loaded).
:- initialization(main, main).
