:- dynamic(counter/1).
counter(0).
bump :- retract(counter(N)), M is N + 1, assertz(counter(M)).
show_all(L) :- member(X, L), write(X), nl, fail.
show_all(_).
safe_div(X, Y, Z) :- catch(Z is X // Y, error(E, _), (write(caught(E)), nl, Z = none)).
main :-
    show_all([a, b]),
    append([1], [2, 3], L), length(L, N), write(N), nl,
    findall(Y, between(1, 3, Y), Ys), write(Ys), nl,
    atom_codes(A, "hi"), write(A), nl,
    bump, bump, counter(C), write(C), nl,
    safe_div(7, 0, Z), write(Z), nl.
:- initialization(main).
