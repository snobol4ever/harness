main :- numlist(1, 5000, Ns), atomic_list_concat(Ns, '-', T), atomic_list_concat(L, '-', T), length(L, N), write(N), nl, last(L, X), write(X), nl.
:- initialization(main).
