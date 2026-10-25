% pl_dead_record_exception_road_u.pl -- the cfo, 2026-10-25. THE DEAD RECORD ON THE EXCEPTION ROAD (ARCH-PROLOG-ACTIVATION-LIFETIME section 6.4 R3): the findall inline in the guarded goal; under the list bag the handler first allocation dies 204 because main/0 RBP records (IR_TO, IR_GATE, IR_BOUND) still root the bag after the ball lands. Want: caught(resource_error(stack)) then after, -d131072k -s4096k, both modes.
:- initialization(main).
main :- catch((findall(f(X), between(1, 9000000, X), L), length(L, N), write(n(N)), nl), error(E, _), (write(caught(E)), nl)), write(after), nl.
