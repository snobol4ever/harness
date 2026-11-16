:- use_module(library(pce)).
:- initialization(main, main).
mask(V, V) :- var(V), !.
mask(@I, @ref) :- integer(I), !.
mask(T, M) :- compound(T), !, T =.. [F|A], maplist(mask, A, B), M =.. [F|B].
mask(T, T).
out(T) :- copy_term(T, T1), mask(T1, T2), numbervars(T2, 0, _), print(T2), nl.
show(E, S) :- E = @_, object(E), !, get(E, class_name, C), ( send(E, has_get_method, value), get(E, value, V) -> S =.. [C, V] ; S = C ).
show(E, E).
elems(C, L) :- chain_list(C, L0), maplist(show, L0, L).
t(N, G) :- write(N), write(': '), ( catch(G, E, (write(caught), write(' '), out(E), fail)) -> true ; write(failed), nl ).
big(E, X) :- X is 2**E - 1.
main :-
  t(atoms, (new(C, chain(a, 'B c', [])), elems(C, L), out(L))),
  t(texts, (new(C1, chain("s", string(abc), string("xyz"), string([0'h, 0'i]))), elems(C1, L1), out(L1))),
  t(numbers, (new(C2, chain(3, -7, 2.5)), elems(C2, L2), out(L2))),
  t(class_args, (new(P, point(3, 4)), get(P, x, X), get(P, y, Y), out(X/Y))),
  t(named, (new(@t2o_p, point(5, 6)), get(@t2o_p, x, X3), out(X3))),
  t(ref_arg, (new(C4, chain(@t2o_p)), get(C4, head, H4), ( H4 == @t2o_p -> out(same) ; out(other) ))),
  t(nested_new, (new(C5, chain(new(point(7, 8)))), get(C5, head, H5), get(H5, y, Y5), out(Y5))),
  t(nested_named, (new(C6, chain(new(@t2o_q, point(9, 10)))), get(@t2o_q, y, Y6), get(C6, size, S6), out(Y6/S6))),
  t(prolog_term, (new(C7, chain(prolog(f(A, b, [1])))), A = 1, get(C7, head, H7), out(H7))),
  t(prolog_numbers, (new(C8, chain(prolog(3), prolog(2.5))), elems(C8, L8), out(L8))),
  t(list_to_chain, (new(C9, chain), send(C9, union, [a, b, c]), elems(C9, L9), out(L9))),
  t(vector, (new(V10, vector(a, b, c)), get(V10, size, S10), get(V10, element, 2, E10), out(S10/E10))),
  t(code_vector, (new(V11, code_vector(1, 2)), get(V11, size, S11), out(S11))),
  t(wide_atom, (atom_codes(U, [228, 8364]), new(C12, chain(U)), get(C12, head, H12), atom_codes(H12, K12), out(K12))),
  t(int_max, (big(62, M), new(C13, chain(M)), elems(C13, L13), out(L13))),
  t(int_low, (X14 is -(2**62), new(C14, chain(X14)), get(C14, head, H14), ( float(H14) -> out(float) ; out(H14) ))),
  t(int_63, (big(63, M15), new(C15, chain(M15)), get(C15, head, H15), ( float(H15) -> out(float) ; out(H15) ))),
  t(no_class, new(_, no_such_class_t2o(1))),
  t(bad_arg_type, new(_, point(a, b))),
  t(no_ref, new(_, chain(@no_such_ref_t2o))),
  t(unbound_arg, new(_, chain(_))),
  t(number_class, new(_, 3)),
  t(redefined, new(@t2o_p, point(1, 1))),
  t(unknown_functor, new(_, chain(f(_)))),
  free(@t2o_p), free(@t2o_q), write(done), nl.
