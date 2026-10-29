:- table a/0, b/0.
a :- write(a_in), nl, tnot(b), write(a_after_tnot_b), nl.
b :- write(b_in), nl, tnot(a), write(b_after_tnot_a), nl.
main :- ( a -> write(a_true) ; write(a_false) ), nl, write(asking_b), nl, ( b -> write(b_true) ; write(b_false) ), nl.
:- initialization(main).
