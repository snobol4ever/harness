%  WITNESS for the Prolog root cell region overlapping the ROOT frame map cell (ceo CEO-953, on the cto's gdb reading).
%  unification.c: PL_DB_CELL0 24, PL_DB_CELLS_MAX 64 -- rt_pl_db_get/rt_pl_nb_set address cell k at (root - 24 - 8k),
%  so 64 cells grow DOWNWARD from root-24.  emit.cpp:3197 places main's ROOT map cell at the jcon value region as a
%  16-byte DT_MAP cell, measured under gdb at root-48 with frame_bytes 272, which is inside that span.
%  MEASURED SHAPE ON MAIN: only the FIRST dynamic predicate keeps its clauses; every later one keeps exactly one.
%  It is RED at SCRIP_GC_STRESS=0, so the primary defect is the overlap itself, not a lost root -- the collector makes
%  it worse (under E the cells sit above the ROOT cell, unvisited, and the registry is reclaimed).
%  The churn/2 loop and the stress band are the second axis: the map cell must still be intact after collections.
%  The .ref is cut from the swipl oracle (swipl -q -t halt), not from ./scrip.
:- initialization(main).
:- dynamic d1/1.
:- dynamic d2/1.
:- dynamic d3/1.
:- dynamic d4/1.
:- dynamic d5/1.
churn(0) :- !.
churn(N) :- atom_codes(_, [97,98,99,100,101,102,103,104]), M is N - 1, churn(M).
main :- assertz(d1(a)), assertz(d1(b)), assertz(d1(c)),
        assertz(d2(a)), assertz(d2(b)), assertz(d2(c)),
        assertz(d3(a)), assertz(d3(b)), assertz(d3(c)),
        assertz(d4(a)), assertz(d4(b)), assertz(d4(c)),
        assertz(d5(a)), assertz(d5(b)), assertz(d5(c)),
        churn(400),
        findall(X, d1(X), L1), length(L1, N1),
        findall(X, d2(X), L2), length(L2, N2),
        findall(X, d3(X), L3), length(L3, N3),
        findall(X, d4(X), L4), length(L4, N4),
        findall(X, d5(X), L5), length(L5, N5),
        write(N1-N2-N3-N4-N5), nl, write('WITNESS'), nl.
