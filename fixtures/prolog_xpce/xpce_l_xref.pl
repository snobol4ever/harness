% L28b: library(prolog_xref) with no window: a small file cross-referenced, its own definitions, its calls, its module, exports, operator and flag
% (xref_op/2 and xref_prolog_flag/4 are the two PceEmacs calls). Its imports are not printed: they are the export list of the library it loads.
:- use_module(library(prolog_xref)).
:- initialization(main, main).
main :-
    absolute_file_name('cmp_xref_subject.pl', F), xref_source(F, [silent(true)]),
    findall(N/A-H, ( xref_defined(F, G, H), H \= imported(_), functor(G, N, A) ), D0), msort(D0, D), print(D), nl,
    findall(N/A-BN/BA, ( xref_called(F, G, B), functor(G, N, A), functor(B, BN, BA) ), C0), msort(C0, C), print(C), nl,
    ( xref_module(F, M) -> print(module(M)) ; print(no_module) ), nl,
    findall(N/A, ( xref_exported(F, E), functor(E, N, A) ), X0), msort(X0, X), print(exported(X)), nl,
    findall(O, xref_op(F, O), Os), print(ops(Os)), nl,
    findall(Fl-V, xref_prolog_flag(F, Fl, V, _), Fs), print(flags(Fs)), nl.
