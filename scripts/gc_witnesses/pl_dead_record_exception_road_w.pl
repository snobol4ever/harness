% pl_dead_record_exception_road_w.pl -- the cfo, 2026-10-25. THE FINDALL COPY GUARD (R3, third class): a 20,000-cell list item copied in one burst past the 4096-byte error reserve; origin exits 2 with [ZHP] REFUSED: rt_pl_dop_findall_add. Want: caught(resource_error(stack)) then after.
:- initialization(main).
main :- catch((findall(S, (between(1, 4000, _), length(S, 20000)), L), length(L, N), write(n(N)), nl), error(E, _), (write(caught(E)), nl)), write(after), nl.
