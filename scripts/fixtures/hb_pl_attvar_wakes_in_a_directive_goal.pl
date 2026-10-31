:- use_module(library(lazy_lists)).
attr_unify_hook(S, V) :- writeln(hook(S, V)).
:- lazy_findall(X, member(X,[1,2,3]), L), L = [A|_], writeln(lazy_first(A)).
:- lazy_findall(X, member(X,[1,2,3]), L), L = [A,B|_], writeln(lazy_two(A,B)).
:- put_attr(X, user, cons), X = [a|_], writeln(after_cons).
:- put_attr(X, user, atom), X = a, writeln(after_atom).
:- put_attr(X, user, struct), X = f(_), writeln(after_struct).
:- freeze(X, writeln(woke_then)), ( X = 1 -> writeln(then) ; writeln(else) ), writeln(end_ite).
:- freeze(X, writeln(woke_neg)), \+ \+ X = 1, writeln(end_neg).
:- freeze(X, fail), ( X = 1 -> writeln(wrong_then) ; writeln(right_else) ).
:- freeze(X, writeln(woke_conj)), X = 1, Y = 2, writeln(conj(Y)).
:- initialization((freeze(X, writeln(woke_init)), X = 1, writeln(after_init))).
:- freeze(X, writeln(woke_last)), X = 1.
