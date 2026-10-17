%  WITNESS for the unification.c descriptor and byte-buffer sites: findall growth (16 -> 64 by doubling), clause cells, atom and code buffers.
:- initialization(main).
:- dynamic f/1.
gen(0) :- !.
gen(N) :- assertz(f(N)), M is N - 1, gen(M).
main :- gen(50), findall(X, f(X), L), length(L, Len), atom_concat(abc, def, A), atom_length(A, AL), sub_atom(A, 1, 3, _, S), atom_codes(S, Cs), atom_codes(S2, Cs), number_codes(Num, [49,50,51]), atom_number(NA, 77),
        findall(Y-Z, (f(Y), Z is Y * 2), L2), length(L2, Len2), findall(Q, (member(Q, [a,b,c]), atom_concat(Q, Q, _)), L3),
        write(Len-AL-S2-Num-NA-Len2-L3), nl, write('WITNESS'), nl.
