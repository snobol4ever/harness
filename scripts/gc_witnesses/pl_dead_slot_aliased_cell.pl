% pl_dead_slot_aliased_cell.pl -- THE ALIASED CELL witness for the dead-slot kill (ARCH-PROLOG-ACTIVATION-LIFETIME section 6.4 R1; hq_prolog 2026-10-25).
% Each clause binds two frame variables to each other while both are unbound (X = Y, or a callee unifying two arguments), gives one
% of them a value, then makes that one's LAST READ a call that is not the last call.  Of two frame cells the younger binds to the
% older (section 6.2), so the other variable's cell may hold a REF to the dying cell: killing the dying cell at its last read would
% leave the live variable naming a null DESCR, and write(Y) would print a fresh variable instead of the value.  swipl prints the
% values; the kill must spare a cell that shares a goal with another variable before its last read.
p(_).
q(A, A).
r(A, B) :- A = B.
t1 :- X = Y, X = 5, p(X), write(Y), nl.
t2 :- Y = X, X = 5, p(X), write(Y), nl.
t3 :- q(X, Y), X = f(1), p(X), write(Y), nl.
t4 :- q(Y, X), X = f(2), p(X), write(Y), nl.
t5 :- r(X, Y), X = g(3), p(X), write(Y), nl.
t6 :- r(Y, X), X = g(4), p(X), write(Y), nl.
t7 :- q(X, Y), p(X), Y = h(5), write(Y), nl.
t8 :- q(X, Y), q(X, Z), Z = k(6), p(X), write(Y), nl.
:- initialization((t1, t2, t3, t4, t5, t6, t7, t8)).
