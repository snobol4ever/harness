:- use_module(library(pce)).
:- initialization(main, main).
mask(V, V) :- var(V), !.
mask(@I, @ref) :- integer(I), !.
mask(T, M) :- compound(T), !, T =.. [F|A], maplist(mask, A, B), M =.. [F|B].
mask(T, T).
out(T) :- copy_term(T, T1), mask(T1, T2), numbervars(T2, 0, _), print(T2), nl.
t(N, G) :- write(N), write(': '), ( catch(G, E, (write(caught), write(' '), out(E), fail)) -> write(yes) ; write(no) ), nl.
main :-
  new(P, point(3, 4)),
  t(var_int, (get(P, x, X), out(X))),
  t(match_int, get(P, x, 3)),
  t(mismatch_int, get(P, x, 4)),
  t(real, (new(R, real(2.5)), get(R, value, RV), out(RV))),
  t(name, (new(C1, chain(hello)), get(C1, head, H1), out(H1))),
  t(name_match, (get(C1, head, hello))),
  t(name_mismatch, (get(C1, head, bye))),
  t(string_var, (new(S, string(abc)), get(S, self, SV), ( SV = @_ -> out(ref) ; out(SV) ))),
  t(string_desc, (object(S, SD), out(SD))),
  t(hostdata, (new(C2, chain(prolog(g(1, [x])))), get(C2, head, H2), out(H2))),
  t(hostdata_match, get(C2, head, g(1, [x]))),
  t(hostdata_mismatch, get(C2, head, g(2, _))),
  t(ref_var, (get(P, self, RP), ( RP = @I, integer(I) -> out(int_ref) ; out(RP) ))),
  t(ref_same, (get(P, self, RP2), RP2 == P)),
  new(@o2t_n, point(1, 2)),
  t(ref_named, (new(C3, chain(@o2t_n)), get(C3, head, @N3), out(N3))),
  t(ref_named_match, get(C3, head, @o2t_n)),
  t(ref_named_mismatch, get(C3, head, @o2t_other)),
  t(struct_match, get(P, self, point(3, 4))),
  t(struct_mismatch, get(P, self, point(3, 5))),
  t(struct_functor, get(P, self, size(3, 4))),
  t(desc_point, (object(P, D), out(D))),
  t(desc_named, (object(@o2t_n, D2), out(D2))),
  free(@o2t_n), write(done), nl.
