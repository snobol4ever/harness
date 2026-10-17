p(1). p(2). p(3).
q(X) :- p(X), X > 1.
main :- findall(X, q(X), L), write(L), nl.
:- initialization(main).
