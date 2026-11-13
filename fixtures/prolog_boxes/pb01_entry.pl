:- initialization(main).
:- dynamic e/1.
t(G) :- catch(( G -> R = yes ; R = no ), error(E, _), ( E = existence_error(_, _) -> R = existence ; R = other )), write(R), nl.
main :- t(e(_)), assertz(e(1)), t(e(_)), retract(e(1)), t(e(_)), t(u(_)), assertz(v(2)), t(v(_)), retract(v(2)), t(v(_)).
