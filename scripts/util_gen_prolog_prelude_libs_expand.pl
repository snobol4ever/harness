/*  util_gen_prolog_prelude_libs_expand.pl -- a vendored SWI library AS SWI ITSELF COMPILES IT: term- and goal-expanded by
    SWI's own loader, printed by portray_clause (cfo 2026-10-10, CEO-1473/1596; row
    prolog-clpfd-library-clpfd-vendored-its-operators-imported-at-the-use-module-directive-...; called by
    util_gen_prolog_prelude_libs.py for a library in its EXPANDED set, never run by hand).

    WHY.  library(clpfd) defines cis/2, cis_lt/2 and cis_leq/2 (172 call sites) ONLY through its own goal_expansion/2, and
    parse_clpfd/3, parse_reified_clpfd/5 and matches/2 ONLY through term_expansion/2 of three facts (make_parse_clpfd.
    make_parse_reified. make_matches.), so the raw file is not the program SWI runs.  This script loads the installed
    library (its term_expansion, goal_expansion and operators), reads the vendored file clause by clause with the
    library's module as the SOURCE module, applies expand_term/2 (term expansion, DCG translation) and expand_goal/2 to
    each body, and prints the result with the module's operators.  optimise_clpfd is switched off for the run so the
    system:goal_expansion hook that specialises #= goals at load does not fire -- SCRIP runs no such hook on user code
    either; what is expanded is the library's own module-local expansion, which defines predicates.  The xref flag is set
    for the run: it is library(apply_macros)' off-switch, whose maplist rewrite calls auxiliary predicates that SWI's
    loader asserts at compile time and a printed text would never carry (measured: 61 such calls without it).

    OPERATORS.  Every :- op directive is printed where it stands (SCRIP's reader registers it as it parses the library),
    and for an operator the directive REDEFINES against the user module's table (clpfd declares => at 800 xfx for its
    parse tables where SWI and SCRIP read => at 1200 xfx as the SSU neck) a restoring :- op directive is printed after
    the last clause, so the library's local operators never leak into the text parsed after it.

    USAGE: swipl util_gen_prolog_prelude_libs_expand.pl -- <vendored file> <lib>     (stdout: the expanded text)
*/
:- initialization(main, main).
main :-
    current_prolog_flag(argv, [File, LibA]),
    atom_string(Lib, LibA),
    use_module(library(Lib)),
    absolute_file_name(library(Lib), Installed, [file_type(prolog), access(read)]),
    (   module_property(M, file(Installed)) -> true ; M = Lib ),
    (   current_prolog_flag(optimise_clpfd, _) -> set_prolog_flag(optimise_clpfd, false) ; true ),
    set_prolog_flag(xref, true),
    '$set_source_module'(Old, M),
    nb_setval('$expand_restores', []),
    setup_call_cleanup(open(File, read, S), expand_all(S, M), close(S)),
    '$set_source_module'(_, Old),
    nb_getval('$expand_restores', Rs),
    reverse(Rs, Restores),
    forall(member(R, Restores), portray_clause(current_output, (:- R), [module(M), quoted(true)])).
expand_all(S, M) :-
    read_term(S, T, [module(M), syntax_errors(error)]),
    (   T == end_of_file -> true
    ;   emit(T, M), expand_all(S, M)
    ).
emit((:- record(R)), M) :- !,
    @(expand_term((:- record(R)), Ts), M),
    (   is_list(Ts) -> Cs = Ts ; Cs = [Ts] ),
    forall(member(C, Cs), emit_clause(C, M)).
emit((:- D), M) :- !,
    (   D = op(P, Ty, N) -> note_restore(P, Ty, N), op(P, Ty, M:N) ; true ),
    portray_clause(current_output, (:- D), [module(M), quoted(true)]).
emit(T, M) :-
    @(expand_term(T, Ts), M),
    (   is_list(Ts) -> Cs = Ts ; Cs = [Ts] ),
    forall(member(C, Cs), emit_clause(C, M)).
emit_clause(C, M) :-
    expand_body(C, M, C1),
    portray_clause(current_output, C1, [module(M), quoted(true)]).
expand_body((H :- B), M, (H :- B1)) :- !, @(expand_goal(B, B1), M).
expand_body((H => B), M, (H => B1)) :- !, @(expand_goal(B, B1), M).
expand_body(C, _, C).
note_restore(P, Ty, N) :-
    op_class(Ty, Class),
    (   current_op(P0, Ty0, user:N), op_class(Ty0, Class), (P0, Ty0) \== (P, Ty)
    ->  nb_getval('$expand_restores', Rs),
        (   memberchk(op(_, _, N), Rs) -> true ; nb_setval('$expand_restores', [op(P0, Ty0, N) | Rs]) )
    ;   true
    ).
op_class(T, infix)   :- memberchk(T, [xfx, xfy, yfx]).
op_class(T, prefix)  :- memberchk(T, [fy, fx]).
op_class(T, postfix) :- memberchk(T, [xf, yf]).
