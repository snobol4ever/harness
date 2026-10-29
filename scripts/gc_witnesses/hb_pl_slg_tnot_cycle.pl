:- table a/0, b/0.
a :- tnot(b).
b :- tnot(a).
main :- ( a -> write(a_true) ; write(a_false) ), nl, ( b -> write(b_true) ; write(b_false) ), nl.
:- initialization(main).
