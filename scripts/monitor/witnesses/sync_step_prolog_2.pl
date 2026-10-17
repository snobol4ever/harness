hello :- write('hello world'), nl.
greet(Name) :- write(hi), write(' '), write(Name), nl.
sq(X, Y) :- Y is X * X.
count(0) :- !.
count(N) :- write(N), nl, M is N - 1, count(M).
sign(X, S) :- ( X < 0 -> S = neg ; X =:= 0 -> S = zero ; S = pos ).
fact(a).
fact(b).
main :- hello, greet(bob), sq(3, Q), write(Q), nl, count(2), sign(-5, S), write(S), nl, fact(F), write(F), nl, ( fact(c) ; write(nope), nl ), \+ fact(z), write(done), nl.
:- initialization(main).
