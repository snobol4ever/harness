main :- length(Cs, 6000), maplist(=(0'x), Cs), atom_codes(A, Cs), atom_codes(A, Cs2), length(Cs2, N), write(N), nl, atom_chars(A, Ch), length(Ch, M), write(M), nl.
:- initialization(main).
