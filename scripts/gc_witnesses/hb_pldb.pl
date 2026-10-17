%  WITNESS for HB_PLDB, HB_PLDBS, HB_PLDBR, HB_PLDBK (216-219) -- the Prolog clause database: registry, key vector, database heads, slot vectors.
:- initialization(main).
:- dynamic fact/2.
churn(0).
churn(N) :- N > 0, assertz(fact(N, z)), M is N - 1, churn(M).
main :- churn(40), retract(fact(20, z)), findall(K, fact(K, z), Ks), length(Ks, 39), nb_setval(w, 'WITNESS'), nb_getval(w, W), write(W), nl.
