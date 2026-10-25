% pl_dead_record_exception_road_v.pl -- the cfo, 2026-10-25. THE CONTROL of R3: the same findall in its own predicate fa/0; its frame is below the floor after the throw and the collection frees the bag. Green on the list-bag build; on origin it dies uncaught at the 64 MB doubling (section 6.5 class 1).
:- initialization(main).
main :- catch(fa, error(E, _), (write(caught(E)), nl)), write(after), nl.
fa :- findall(f(X), between(1, 9000000, X), L), length(L, N), write(n(N)), nl.
