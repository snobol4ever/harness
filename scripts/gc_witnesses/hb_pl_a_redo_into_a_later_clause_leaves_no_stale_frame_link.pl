:- initialization(main).
:- dynamic p/1.
p(X) :- X = 1.
p(X) :- atom_codes(A, "abcdefghij"), atom_length(A, L), atom_codes(B, [0'x, 0'y, 0'z]), atom_concat(A, B, C), atom_length(C, M), X = L-M-B.
main :- p(X), X \== 1, write(X), nl.
