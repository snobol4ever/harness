:- module(cmp_expand, []).
:- multifile user:term_expansion/2, system:term_expansion/2, user:goal_expansion/2.
:- dynamic user:term_expansion/2, system:term_expansion/2, user:goal_expansion/2.
user:term_expansion(foo(X), bar(X)).
system:term_expansion(baz(X), qux(X)).
system:term_expansion(emit(X), (:- initialization(writeln(emitted(X))))).
user:goal_expansion(hello, writeln(expanded_hello)).
user:term_expansion(where(X), located(F, L, X)) :- source_location(P, L), file_base_name(P, F).
