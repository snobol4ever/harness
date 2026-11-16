% The kernel's memory under churn: blocks of many sizes made, grown, released and made again
% (objects, a string that grows, a vector that grows, a hash table that rehashes).
% No display is needed and no integer reference is printed.
:- use_module(library(pce)).

points(N, Round) :-
    new(C, chain),
    forall(between(1, N, I), ( Y is I * Round, send(C, append, new(_, point(I, Y))) )),
    get(C, size, Size),
    get(C, tail, T), get(T, y, TY),
    format("points ~w: ~w tail_y ~w~n", [Round, Size, TY]),
    send(C, for_all, message(@arg1, free)),
    free(C).

grow_string(N) :-
    new(S, string),
    forall(between(1, N, I), ( C is 0'a + I mod 26, char_code(A, C), send(S, append, A) )),
    get(S, size, L),
    get(S, sub, 0, 30, Sub), get(Sub, value, V),
    format("string ~w ~w~n", [L, V]),
    send(S, truncate, 5), get(S, value, V5), format("truncated ~w~n", [V5]),
    forall(between(1, 200, _), send(S, append, 'xyz-')),
    get(S, size, L2), format("regrown ~w~n", [L2]),
    free(S).

sized_strings(N) :-
    new(C, chain),
    forall(between(1, N, I),
           ( L is (I * 37) mod 1500 + 1, new(S, string), send(S, insert_character, 0'q, 0, L), send(C, append, S) )),
    new(Sum, number(0)),
    send(C, for_all, message(Sum, plus, @arg1?size)),
    get(Sum, value, Total),
    format("sized ~w total ~w~n", [N, Total]),
    send(C, for_all, message(@arg1, free)),
    free(C), free(Sum).

grow_vector(N) :-
    new(V, vector),
    forall(between(1, N, I), ( X is I * I, send(V, element, I, X) )),
    get(V, size, Size), get(V, element, N, Last), get(V, element, 1, First),
    format("vector ~w first ~w last ~w~n", [Size, First, Last]),
    free(V).

table(N) :-
    new(H, hash_table),
    forall(between(1, N, I), ( atom_concat(key_, I, K), V is I * 3, send(H, append, K, V) )),
    get(H, size, S1),
    get(H, member, key_1234, V1234),
    forall(( between(1, N, I), I mod 2 =:= 0 ), ( atom_concat(key_, I, K), send(H, delete, K) )),
    get(H, size, S2),
    ( get(H, member, key_1234, _) -> In = still ; In = gone ),
    get(H, member, key_1233, V1233),
    format("table ~w then ~w; key_1234 ~w ~w; key_1233 ~w~n", [S1, S2, V1234, In, V1233]),
    free(H).

main :-
    points(2000, 1),
    points(2000, 2),
    grow_string(3000),
    sized_strings(600),
    grow_vector(4000),
    table(3000),
    points(2000, 3),
    sized_strings(600),
    format("done~n").

:- initialization((main -> halt ; halt(1))).
