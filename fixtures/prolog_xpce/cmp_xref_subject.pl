:- module(xref_subject, [double/2, (===>)/2]).
:- use_module(library(lists)).
:- op(700, xfx, ===>).
:- set_prolog_flag(double_quotes, codes).
double(X, Y) :- Y is X * 2.
twice(L, M) :- maplist(double, L, M), last(M, _).
A ===> B :- twice(A, B), \+ undefined_here(B).
