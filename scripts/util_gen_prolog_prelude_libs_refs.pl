/*  util_gen_prolog_prelude_libs_refs.pl -- the PREDICATE REFERENCES of a vendored SWI library, read by SWI's own reader
    (cfo 2026-10-10, CEO-1473; called by util_gen_prolog_prelude_libs.py, never run by hand).

    WHY SWI READS IT.  The generator renames a library's unexported predicates '$<lib>_<name>'.  A name is often ALSO data
    in the same library -- library(error) has a helper text/1 and the type name text in has_type(text, X) -- so renaming
    every atom of that name corrupts the data, and a token scan cannot tell a goal from a term.  SWI's reader can: it
    reads each clause with subterm_positions (the character span of every subterm) under the library's own operators,
    and this file walks the clause's GOAL positions only -- the head, a body goal, a goal argument of a control construct
    or of a meta-predicate (its meta_predicate/1 spec from the loaded library or the system: 0 a goal, N a closure taking
    N more arguments, ^ a bagof goal, // a DCG body, : a HEAD -- clause/2's first argument, assert's clause, a Name/Arity
    indicator), a yall lambda's body, a DCG rule's nonterminals and {}/1 goals.
    Anything else is data and is never reported, so it is never renamed.

    OUTPUT, one line per item, offsets in characters of the file, the name LAST and unquoted:
      C <From> head <Arity> <Name>   a clause (a DCG rule's arity counts its two list arguments)
      C <From> directive 0 -        a directive;  C <From> qualified 0 -  a module-qualified head;  C <From> unkeyable 0 -
      R <From> <To> <Arity> a|c <Name>   a predicate reference spanning [From,To): a an atom, c a compound's functor (the
                                         generator refuses to rename a c span not written name( -- an operator form)
    The library is loaded from SWI's own library directory first, so its operators and meta-predicate declarations are
    known, and read in the module that file declares (library(option) is module swi_option); the vendored file must be
    byte-identical to that copy or this refuses (exit 2).  An optional THIRD argument names the file to READ instead
    (the generator's EXPANDED mode, cfo 2026-10-10, row prolog-clpfd-library-clpfd-vendored-...-ceo-1596: the text SWI
    itself compiles, written by util_gen_prolog_prelude_libs_expand.pl); the identity check stays on the vendored file.
*/
:- initialization(main, main).

main :-
    current_prolog_flag(argv, [File, LibA | Rest]),
    (   Rest = [ReadFileA] -> atom_string(ReadFile, ReadFileA) ; ReadFile = File ),
    atom_string(Lib, LibA),
    absolute_file_name(library(Lib), Installed, [file_type(prolog), access(read)]),
    read_file_to_codes(File, C1, []), read_file_to_codes(Installed, C2, []),
    (   C1 == C2 -> true
    ;   format(user_error, "REFUSED(2): ~w differs from swipl's own ~w -- the meta-predicate declarations read would not be the vendored file's~n", [File, Installed]),
        halt(2)
    ),
    use_module(library(Lib)),
    (   module_property(M, file(Installed)) -> true ; M = Lib ),
    setup_call_cleanup(open(ReadFile, read, S), read_all(S, M), close(S)).

read_all(S, M) :-
    read_term(S, T, [subterm_positions(P), module(M), syntax_errors(error)]),
    (   T == end_of_file -> true
    ;   clause_refs(T, P, M), read_all(S, M)
    ).

clause_refs((:- D), P, M) :- !,
    arg(1, P, From), format("C ~d directive 0 -~n", [From]),
    (   D = op(Pr, Ty, Nm) -> op(Pr, Ty, M:Nm) ; true ).
clause_refs((H --> B), P0, M) :- unparen(P0, term_position(From, _, _, _, [HP, BP])), !,
    dcg_head(H, HP, HB, HBP),
    head_ref(HB, HBP, 2, From),
    dcg_body(B, BP, M).
clause_refs((H => B), P0, M) :- unparen(P0, term_position(From, _, _, _, [HP, BP])), !,
    (   H = (H0, G), unparen(HP, term_position(_, _, _, _, [H0P, GP])) -> head_ref(H0, H0P, 0, From), goal(G, GP, M)
    ;   head_ref(H, HP, 0, From)
    ),
    goal(B, BP, M).
clause_refs((H :- B), P0, M) :- unparen(P0, term_position(From, _, _, _, [HP, BP])), !,
    head_ref(H, HP, 0, From),
    goal(B, BP, M).
clause_refs(H, P, _) :-
    arg(1, P, From),
    head_ref(H, P, 0, From).

dcg_head((H, _), P, H, HP) :- unparen(P, term_position(_, _, _, _, [HP, _])), !.
dcg_head(H, P, H, P).

head_ref(_:_, _, _, From) :- !, format("C ~d qualified 0 -~n", [From]).
head_ref(H, P, Extra, From) :-
    (   callable(H) -> functor(H, N, A0), A is A0 + Extra, format("C ~d head ~d ~w~n", [From, A, N]), ref(H, P, Extra)
    ;   format("C ~d unkeyable 0 -~n", [From])
    ).

unparen(parentheses_term_position(_, _, P0), P) :- !, unparen(P0, P).
unparen(P, P).

ref(T, P0, Extra) :-
    unparen(P0, P),
    (   atom(T), P = F-To -> format("R ~d ~d ~d a ~w~n", [F, To, Extra, T])
    ;   compound(T), P = term_position(_, _, FF, FT, _) -> compound_name_arity(T, N, A0), A is A0 + Extra, format("R ~d ~d ~d c ~w~n", [FF, FT, A, N])
    ;   true
    ).

control((_,_)).  control((_;_)).  control((_->_)).  control((_*->_)).  control(\+ _).  control(_:_).  control((_|_)).

goal(G, _, _) :- var(G), !.
goal(G, P0, M) :- unparen(P0, P),
    (   control(G) -> P = term_position(_, _, _, _, APs), G =.. [_|As], control_args(G, As, APs, M)
    ;   callable(G) ->
        ref(G, P, 0),
        meta_args(G, P, M)
    ;   true
    ).

control_args(_:G, [_, G], [_, GP], M) :- !, goal(G, GP, M).
control_args(_, As, APs, M) :- maplist({M}/[A, AP]>>goal(A, AP, M), As, APs).

meta_args(G, P, M) :-
    compound(G),
    P = term_position(_, _, _, _, APs),
    (   catch(predicate_property(M:G, meta_predicate(Spec)), _, fail) -> true
    ;   catch(predicate_property(system:G, meta_predicate(Spec)), _, fail) -> true
    ;   fail
    ),
    !,
    G =.. [_|As], Spec =.. [_|Ss],
    maplist({M}/[A, AP, Sp]>>meta_arg(Sp, A, AP, M), As, APs, Ss).
meta_args(_, _, _).

meta_arg(0, A, AP, M) :- !, goal(A, AP, M).
meta_arg(^, A, AP, M) :- !, caret_goal(A, AP, M).
meta_arg(//, A, AP, M) :- !, dcg_body(A, AP, M).
meta_arg(N, A, AP, M) :- integer(N), N > 0, !, closure(A, AP, N, M).
meta_arg(:, A, AP, M) :- !, head_arg(A, AP, M).
meta_arg(_, _, _, _).

head_arg(H, _, _) :- var(H), !.
head_arg(_:H, P0, M) :- unparen(P0, term_position(_, _, _, _, [_, HP])), !, head_arg(H, HP, M).
head_arg((H :- B), P0, M) :- unparen(P0, term_position(_, _, _, _, [HP, BP])), !, head_arg(H, HP, M), goal(B, BP, M).
head_arg(N/A, P0, _) :- atom(N), integer(A), unparen(P0, term_position(_, _, _, _, [NP, _])), !, unparen(NP, F-T), format("R ~d ~d ~d a ~w~n", [F, T, A, N]).
head_arg(H, P, _) :- callable(H), !, ref(H, P, 0).
head_arg(_, _, _).

caret_goal(G, _, _) :- var(G), !.
caret_goal(_^G, P0, M) :- unparen(P0, term_position(_, _, _, _, [_, GP])), !, caret_goal(G, GP, M).
caret_goal(G, P, M) :- goal(G, P, M).

closure(C, _, _, _) :- var(C), !.
closure(_:C, P0, N, M) :- unparen(P0, term_position(_, _, _, _, [_, CP])), !, closure(C, CP, N, M).
closure(_>>B, P0, _, M) :- unparen(P0, term_position(_, _, _, _, [_, BP])), !, goal(B, BP, M).
closure(_/L, P0, N, M) :- unparen(P0, term_position(_, _, _, _, [_, LP])), !, closure(L, LP, N, M).
closure(C, P, N, _) :- callable(C), !, ref(C, P, N).
closure(_, _, _, _).

dcg_body(B, _, _) :- var(B), !.
dcg_body(B, P0, M) :- unparen(P0, P),
    (   B = (X,Y) -> P = term_position(_, _, _, _, [XP, YP]), dcg_body(X, XP, M), dcg_body(Y, YP, M)
    ;   B = (X;Y) -> P = term_position(_, _, _, _, [XP, YP]), dcg_body(X, XP, M), dcg_body(Y, YP, M)
    ;   B = (X|Y) -> P = term_position(_, _, _, _, [XP, YP]), dcg_body(X, XP, M), dcg_body(Y, YP, M)
    ;   B = (X->Y) -> P = term_position(_, _, _, _, [XP, YP]), dcg_body(X, XP, M), dcg_body(Y, YP, M)
    ;   B = (\+ X) -> P = term_position(_, _, _, _, [XP]), dcg_body(X, XP, M)
    ;   B = {G} -> P = brace_term_position(_, _, GP), goal(G, GP, M)
    ;   B = call(C) -> P = term_position(_, _, _, _, [CP]), closure(C, CP, 2, M)
    ;   B = call(C, _) -> P = term_position(_, _, _, _, [CP, _]), closure(C, CP, 3, M)
    ;   B == ! -> true
    ;   B == [] -> true
    ;   is_list(B) -> true
    ;   string(B) -> true
    ;   callable(B) -> ref(B, P, 2)
    ;   true
    ).
