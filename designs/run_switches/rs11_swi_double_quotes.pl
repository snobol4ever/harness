:- initialization(main).
main :- X = "abc", ( string(X) -> write(string) ; write(other) ), nl, last([1,2,3], L), write(L), nl.
