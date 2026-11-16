:- use_module(library(pce)).
:- initialization(main, main).
:- pce_begin_class(o2t_pair, object).
variable(l, any, both).
variable(r, any, both).
initialise(P, L:any, R:any) :-> send_super(P, initialise), send(P, l, L), send(P, r, R).
functor(_P, F:name) :<- write(read(functor)), nl, F = pr.
'_arity'(_P, A:int) :<- write(read(arity)), nl, A = 2.
'_arg'(P, N:int, V:any) :<- write(read(arg(N))), nl, ( N == 1 -> get(P, l, V) ; get(P, r, V) ).
:- pce_end_class.
mask(V, V) :- var(V), !.
mask(@I, @ref) :- integer(I), !.
mask(T, M) :- compound(T), !, T =.. [F|A], maplist(mask, A, B), M =.. [F|B].
mask(T, T).
out(T) :- copy_term(T, T1), mask(T1, T2), numbervars(T2, 0, _), print(T2), nl.
t(N, G) :- write(N), write(': '), ( catch(G, E, (write(caught), write(' '), out(E), fail)) -> write(yes) ; write(no) ), nl.
main :-
  new(Q, o2t_pair(1, 2)),
  t(reads_var, (object(Q, DQ), out(DQ))),
  t(reads_match, get(Q, self, pr(1, 2))),
  t(reads_mismatch_arg1, get(Q, self, pr(9, 2))),
  t(reads_mismatch_functor, get(Q, self, qq(1, 2))),
  t(reads_mismatch_arity, get(Q, self, pr(1))),
  write(done), nl.
