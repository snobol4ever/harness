% pl_user_between_shadows_the_prelude.pl -- THE PRELUDE SCOPE witness (the cfo, 2026-10-25; row prolog-xsb-package-delay-and-wfs-programs-equal-swipl, xsb_tests delay_tests_gfp).
% The program defines between/3 with XSB's argument order, between(Low, X, High), exactly as delay_tests_gfp does.  swipl's
% library(tabling) keeps calling system:between/3 inside its own module, so a tabled call and tnot/1 still answer, while the
% program's own between(3,Y,4) runs its clauses.  SCRIP routed the tabling prelude's own between/3 calls to the program's clauses
% and raised instantiation_error from inside the prelude (measured 2026-10-25 at SCRIP a71841eba: cases 1 and 2 caught).
% The ref is swipl 9.0.4's output.  Cured when a program's definition of a system or library predicate reaches only the program's
% own clauses, never the prelude's.
between(L,L,H) :- L=<H.
between(L,M,H) :- L<H, L1 is L+1, between(L1,M,H).
:- table g/1.
g(1).
g(2).
pr1(N, G) :- ( catch(G, E, (write(N-caught(E)), nl, fail)) -> write(N-yes), nl ; write(N-no), nl ).
:- initialization((pr1(1, (findall(X, g(X), L), msort(L, S), write(S), nl)), pr1(2, tnot(g(3))), pr1(3, (findall(Y, between(3,Y,4), Ys), write(Ys), nl)), halt)).
