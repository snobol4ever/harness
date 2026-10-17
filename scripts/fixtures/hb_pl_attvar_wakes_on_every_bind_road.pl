:- initialization(main).
w(T, X) :- write(T), write(' woke '), writeq(X), nl.
p(1).
q(f(_)).
r(A, A).
p2(1).
p2(2).
attr_unify_hook(even, Y) :- integer(Y), 0 is Y mod 2.
s01 :- freeze(X, w(s01, X)), p(X).
s02 :- freeze(X, w(s02, X)), q(X).
s03 :- freeze(X, w(s03, X)), r(X, 5).
s04 :- freeze(X, w(s04, X)), X = 7.
s05 :- freeze(X, w(s05, X)), f(X, b) = f(3, b).
s06 :- freeze(X, w(s06, X)), f(3, b) = f(X, b).
s07 :- freeze(X, w(s07, X)), X = Y, write(s07_bound_plain), nl, Y = 9.
s08 :- freeze(X, w(s08, X)), Y = X, write(s08_bound_plain), nl, Y = 10.
s09 :- freeze(X, w(s09a, X)), freeze(Y, w(s09b, Y)), X = Y, write(s09_joined), nl, X = 11.
s10 :- freeze(X, w(s10, X)), functor(X, f, 2).
s11 :- freeze(Z, w(s11, Z)), arg(1, f(Z), 5).
s12 :- freeze(X, w(s12, X)), X =.. [g, 1].
s13 :- freeze(X, w(s13, X)), X is 3 + 4.
s14 :- freeze(L, L = [1, 2, 3]), memberchk(2, L), writeq(s14(L)), nl.
s15 :- freeze(X, w(s15, X)), ( f(X, a) = f(1, b) -> write(s15_unified) ; write(s15_failed_no_wake) ), nl.
s16 :- freeze(X, X > 1), p2(X), writeq(s16(X)), nl.
s17 :- dif(A, b), ( A = b -> writeq(s17_unified) ; writeq(s17_dif_blocks) ), nl.
s18 :- dif(f(P, Q), f(1, 2)), P = 1, ( Q = 2 -> writeq(s18_unified) ; writeq(s18_dif_blocks) ), nl.
s19 :- when(ground(g(M, N)), (write(s19_ground(M, N)), nl)), M = 1, writeq(s19_waiting), nl, N = 2.
s20 :- put_attr(V, user, even), get_attr(V, user, Att), writeq(s20(Att)), nl, ( V = 4 -> writeq(s20_even_ok) ; writeq(s20_even_no) ), nl.
s21 :- put_attr(W, user, even), ( W = 3 -> writeq(s21_odd_ok) ; writeq(s21_odd_rejected) ), nl.
s22 :- freeze(X, w(s22, X)), frozen(X, G), writeq(s22(G)), nl, X = a.
s23 :- X = 5, freeze(X, w(s23, X)).
s24 :- put_attr(V, user, even), del_attr(V, user), ( attvar(V) -> writeq(s24_still) ; writeq(s24_plain) ), nl, V = 3, writeq(s24(V)), nl.
s25 :- freeze(X, w(s25, X)), ( X = 1 ; X = 2 ), X == 2, writeq(s25_second), nl.
s26 :- freeze(X, fail), ( X = 1 -> writeq(s26_bound) ; writeq(s26_wake_failed) ), nl.
s27 :- freeze(X, w(s27, X)), atom_length(abc, X).
s28 :- freeze(X, w(s28, X)), copy_term(X, Y), Y = 1, writeq(s28_copy_bound), nl, X = 2.
s29 :- freeze(X, w(s29, X)), G = (f(X) = f(1)), call(G), write(s29_after), nl.
s30 :- freeze(X, w(s30, X)), unifiable(f(X, b), f(1, B), U), writeq(s30(U)), nl, var(X), var(B), write(s30_unbound), nl.
s31 :- dif(A, b), ( A \= b -> writeq(s31_neq) ; writeq(s31_eq) ), nl.
s32 :- G = (freeze(X, throw(boom)), X = 1), catch(G, E, (writeq(s32_caught(E)), nl)).
s33 :- G = (freeze(Y, w(s33, Y)), Y = 1, write(s33_after), nl), call(G).
main :- forall(member(G, [s01, s02, s03, s04, s05, s06, s07, s08, s09, s10, s11, s12, s13, s14, s15, s16, s17, s18, s19, s20, s21, s22, s23, s24, s25, s26, s27, s28, s29, s30, s31, s32, s33]),
               ( catch(G, E, (write(G), write(' raised '), writeq(E), nl)) -> true ; write(G), write(' failed'), nl )).
