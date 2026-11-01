loop(0, _) :- !.
loop(N, _) :- M is N - 1, loop(M, _).
ping(N) :- N > 0, M is N - 1, pong(M, _).
ping(0).
pong(M, _) :- ping(M).
:- loop(1000000, _), write(plain_loop_done), nl.
:- ping(1000000), write(mutual_loop_done), nl.
