:- use_module(library(lists)).
:- prolog_load_context(directory, D), asserta(user:file_search_path(wroot, D)), assertz(user:file_search_path(library, D)).
user:file_search_path(wsub, wroot('.')).
:- use_module(wroot(cmp_module_a)).
:- use_module(library(cmp_module_b)).
:- use_module(wsub(cmp_module_c)).
:- use_module(library(debug)).
:- catch(use_module(library(no_such_lib_xyz)), error(F, _), (print(load(F)), nl)).
r(a ===> b).
dbg(X) :- debug(wtopic, "debug ~w", [X]).
t(N, G) :- write(N), write(': '), ( catch(G, error(F, _), (print(caught(F)), nl, fail)) -> true ; write(no), nl ).
main :-
    t(1, (pa(X1), print(X1), nl)),
    t(2, (pb(X2), print(X2), nl)),
    t(3, (pc(X3), print(X3), nl)),
    t(4, (r(R), writeq(R), nl)),
    t(5, (current_op(P, T, ===>), print(op(P, T)), nl)),
    t(6, use_module(library(no_such_lib_xyz))),
    t(7, (consult([wroot(cmp_plain_d), wroot(cmp_plain_e)]), pd(D), pe(E), print(D-E), nl)),
    t(8, load_files(wroot(no_such_file_xyz), [])),
    t(9, (load_files(wsub(cmp_module_c), [if(not_loaded)]), print(again), nl)),
    debug(wtopic), dbg(ran), nodebug(wtopic), dbg(never_printed),
    t(10, (print(debug_done), nl)).
:- initialization(main, main).
