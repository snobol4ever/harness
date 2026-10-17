% the Prolog trail's cap (PL_TR_ARENA_LG2 29: 16777215 conditional bindings, 512 MB since 3d08ec2c8) read past the cap -- 17200000
% variables older than a choicepoint, each bound once, in chunks of 4000; length/2 over 17200000 cells needs the 8 GB virtual stack
% the row declares (measured 2.0 GB resident, 6.4 s). A legal program: swipl (--stack-limit=8g) prints done.
% SCRIP refuses at the cap, loudly (rc 2).
:- initialization(main).
main :- length(L, 17200000), ( true ; true ), bind_all(L), write(done), nl, halt.
bind_all([]) :- !.
bind_all(L) :- take(4000, L, Rest), bind_all(Rest).
take(0, R, R) :- !.
take(_, [], []) :- !.
take(N, [a|T], R) :- N1 is N - 1, take(N1, T, R).
