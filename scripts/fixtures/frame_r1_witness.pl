q(1).
q(2).
r(N) :- N > 0, q(_), N1 is N-1, r(N1).
r(0).
:- initialization(main).
main :- r(5), write(ok), nl.
