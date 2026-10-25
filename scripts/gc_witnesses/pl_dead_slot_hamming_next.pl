% pl_dead_slot_hamming_next.pl -- THE DEAD SLOT witness (ARCH-PROLOG-ACTIVATION-LIFETIME section 6, the cfo 2026-10-25).
% main/1 builds the Hamming generator's initial state G and hands it to run/2 as the LAST READ of G; G is never read again,
% yet main's frame cell for G holds hamm(1,X,1,X,1,X,X) whose X is bound to the head of the Hamming list, so every list
% cell run/2 ever produces stays reachable from a cell no clause reads: 48 bytes per iteration, swipl flat at 12 MB.
% Cured when the cell is released at its last read (section 6.4 R1) -- the window never grows (grew=0 at -i2048k).
% The program's own output is one line, done, so the gate grades the GC-EXERCISE line and nothing else.
run(0, _) :- !.
run(N, G) :- N > 0, !, next(G, _, G1), N1 is N-1, run(N1, G1).
next( hamm( A2,B,C3,D,E5,F,[H|G] ), H, hamm(X,U,Y,V,Z,W,G) ):-
  H is min(A2, min(C3,E5)),
  (   A2 =:= H -> B=[N2|U],X is N2*2 ; (X,U)=(A2,B) ),
  (   C3 =:= H -> D=[N3|V],Y is N3*3 ; (Y,V)=(C3,D) ),
  (   E5 =:= H -> F=[N5|W],Z is N5*5 ; (Z,W)=(E5,F) ).
mkHamm( hamm(1,X,1,X,1,X,X) ).
main(N) :- mkHamm(G), run(N, G), write(done), nl.
:- initialization(main(200000)).
