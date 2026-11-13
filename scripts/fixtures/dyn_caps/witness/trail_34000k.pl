% the Prolog trail's cap (PL_TR_ARENA_LG2 30: 33554431 conditional bindings, 1 GB since CTO-638) read past the cap -- 34000000
% variables older than a choicepoint, each bound once, in chunks of 4000; length/2 over 34000000 cells needs stack_limit raised past
% its 1 GB default, set by the program (measured 2026-11-12: SCRIP 4.0 GB resident, 62 s to the refusal). A legal program: swipl prints done.
% SCRIP refuses at the cap, loudly (rc 2).
:- initialization(main).
main :- set_prolog_flag(stack_limit, 8589934592), length(L, 34000000), ( true ; true ), bind_all(L), write(done), nl, halt.
bind_all([]) :- !.
bind_all(L) :- take(4000, L, Rest), bind_all(Rest).
take(0, R, R) :- !.
take(_, [], []) :- !.
take(N, [a|T], R) :- N1 is N - 1, take(N1, T, R).
