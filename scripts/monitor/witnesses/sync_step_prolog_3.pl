hello :-
    write('hello world'),
    nl.
twice(X, Y) :-
    Y is X * 2,
    write(Y),
    nl.
main :-
    hello,
    twice(21, _),
    write(done), nl.
:- initialization(main).
