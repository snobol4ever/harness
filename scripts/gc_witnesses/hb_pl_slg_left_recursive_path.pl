:- table path/2.
e(1,2). e(2,3). e(3,1).
path(X,Y) :- e(X,Y).
path(X,Y) :- path(X,Z), e(Z,Y).
:- initialization((findall(X-Y, path(X,Y), L), msort(L, S), write(S), nl)).
