:- import append/3 from basics.
:- initialization(main).
main :- append([1],[2],L), write(L), nl.
