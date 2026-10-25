% pl_open_tail_difference_list.pl -- THE INTERIOR REFERENCE witness (ARCH-PROLOG-ACTIVATION-LIFETIME section 6, the cfo 2026-10-25).
% mk/1 threads a difference list with an OPEN tail through a last-call loop: the tail variable Z is the second cell of
% the first pair block _-_, whose first cell is bound to the head of the list.  Every later pair B-Z carries a reference
% to Z, the collector marks the pair block whole, the pair's first cell marks the list head, and the whole list stays:
% 48 bytes per iteration, swipl flat at 7 MB.  With the tail closed (L = _-[]) the same loop is flat in SCRIP too.
% Cured when a reference into a block traces the referenced cell alone (section 6.4 R2) -- grew=0 at -i2048k.
loop(0, Z-Z) :- !.
loop(N, [A|B]-Z) :- N>0, !, A = N, N1 is N-1, loop(N1, B-Z).
mk(N) :- loop(N, _-_).
main(N) :- mk(N), write(done), nl.
:- initialization(main(200000)).
