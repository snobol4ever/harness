:- dynamic(foo/1).
:- initialization(main).
bar(1).
bar(X) :- foo(X), X > 0.
baz :- write(hi), nl.
main :- assertz(foo(a)), assertz((foo(Y) :- bar(Y), !)), listing, write(end), nl, halt.
