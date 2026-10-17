%  WITNESS for the by_name_dispatch.c atom-dup site -- pl_mk_atom_dup's byte block is HB_WSB (ATOMIC).
%  The DT_S descriptor points AT the block; the block itself holds no pointers, so the collector must
%  still mark, forward and RELOCATE it, and must never scan its interior.  A and B are built BEFORE the
%  churn and read back AFTER it, so a lost forwarding address shows up as corrupted text, not as a crash.
%  ⛔ The churn stays inside atoms on purpose: swipl's atom_concat coerces an integer argument and SCRIP's
%  does not, so a churn written with a number would grade that divergence instead of the collector.
:- initialization(main).
churn(0).
churn(N) :- N > 0, L is N mod 9 + 1, sub_atom(abcdefghij, 0, L, _, _), M is N - 1, churn(M).
main :- atom_concat(alpha, omega, A),
        sub_atom(abcdefghij, 2, 5, _, B),
        churn(400),
        atom_concat(A, B, C),
        write(A), nl, write(B), nl, write(C), nl.
