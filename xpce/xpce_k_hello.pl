:- use_module(library(pce)).
:- initialization(main).
main :-
    new(P, picture),
    send(P, display, new(_, box(160, 90)), point(30, 30)),
    send(P, display, new(_, text('Hello from the kernel')), point(30, 140)),
    send(P, open),
    read(user_input, _).
