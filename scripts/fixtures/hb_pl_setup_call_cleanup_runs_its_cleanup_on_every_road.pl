:- dynamic(v/1).
det(1).
ndet(a). ndet(b). ndet(_) :- 1 =:= 0.
pend(X) :- setup_call_cleanup(true, member(X, [a,b,c]), (write(cleanup_pend), nl)).
cl(T) :- write(cleanup(T)), nl.
p3(L) :- numlist(1, 5, L), setup_call_cleanup(true, member(_, [a,b,c]), cl(heap(L))).
t01 :- setup_call_cleanup(true, det(_), cl(det_exit)), write(after_det), nl.
t02 :- setup_call_cleanup(true, ndet(_), cl(not_at_exit)), write(after_ndet_exit), nl, !, write(after_cut), nl.
t03 :- ( setup_call_cleanup(true, ndet(X), cl(exhausted)), write(sol(X)), nl, fail ; write(after_exhaustion), nl ).
t04 :- catch((setup_call_cleanup(true, (G=1;G=2), cl(ball_after_exit)), throw(first)), B, (write(caught(B)), nl)).
t05 :- catch(setup_call_cleanup(true, throw(inside), cl(ball_inside)), B, (write(caught(B)), nl)).
t06 :- catch((setup_call_cleanup(true, (G=1;G=2), throw(second)), throw(first)), B, (write(caught(B)), nl)).
t07 :- retractall(v(_)), catch(t07b, E, true), findall(X, retract(v(X)), [x(S, G, B)]), ( var(G) -> VG = unbound ; VG = G ), ( var(B) -> VB = unbound ; VB = B ), write(t07(E, S, VG, VB)), nl.
t07b :- setup_call_cleanup(S=1, (G=2;G=3), asserta(v(x(S,G,B)))), B = 4, throw(x).
t08 :- setup_call_cleanup(true, setup_call_cleanup(true, (X=1;X=2), cl(inner)), cl(outer)), !, write(t08(X)), nl.
t09 :- ( setup_call_cleanup(true, fail, cl(g_failed)) -> write(then) ; write(else) ), nl.
t10 :- \+ setup_call_cleanup(true, fail, cl(negated)), write(negation_ok), nl.
t11 :- catch(( pend(X), X == b, throw(t) ), t, (write(caught_after_redo), nl)).
t12 :- catch(( p3(_), throw(t) ), t, (write(caught_heap), nl)).
t13 :- ( pend(X), X == b -> write(found(X)) ; write(none) ), nl.
t14 :- call((pend(X), !)), write(callcut(X)), nl.
t15 :- catch((pend(X), !), _, true), write(catchcut(X)), nl.
t16 :- once(setup_call_cleanup(open('scc_witness.tmp', write, S), member(_, [1,2]), close(S))), ( catch(write(S, x), _, (write(closed_at_once), nl)) -> true ; write(still_open), nl ).
t17 :- ( setup_call_cleanup(true, ndet(_), D = true) -> true ; true ), write(t17(D)), nl.
t18 :- ( true -> setup_call_cleanup(true, member(_, [1,2]), cl(gate_arm)) ; true ), catch(throw(z), _, true), write(t18), nl.
run :- t01, t02, t03, t04, t05, t06, t07, t08, t09, t10, t11, t12, t13, t14, t15, t16, t17, t18.
:- initialization((run, halt)).
