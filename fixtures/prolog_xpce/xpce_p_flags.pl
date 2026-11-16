:- module(xpce_p_flags, [r/1]).
:- require([member/2, append/3]).
:- autoload(library(lists), [last/2]).
:- at_halt(writeln(at_halt_ran)).
:- license(lgpl).
:- reexport(library(lists), [sum_list/2]).
:- predicate_options(r/1, 1, [depth(integer)]).
r(x).
:- unlock_predicate(r/1).
:- '$set_predicate_attribute'(r(_), hide_childs, false).
flag(F) :-
    (   catch(current_prolog_flag(F, V), error(E, _), (print(F-raised(E)), nl, fail))
    ->  writeq(F = V), nl
    ;   writeq(F - fails), nl
    ).
atom_flag(F) :-
    (   catch(current_prolog_flag(F, V), error(E, _), (print(F-raised(E)), nl, fail))
    ->  ( atom(V) -> writeq(F - atom) ; writeq(F - not_atom) ), nl
    ;   writeq(F - fails), nl
    ).
main :-
    flag(no_such_flag_xyz),
    forall(member(F, [access_level, address_bits, answer_write_options, autoload,
                      character_escapes, debug_on_error, editor, generate_debug_info,
                      open_shared_object, unix, version, xref, xpce, debug, version_data]),
           flag(F)),
    atom_flag(home), atom_flag(executable),
    ( current_prolog_flag(version_data, swi(Ma, Mi, Pa, _)) -> writeq(swi(Ma, Mi, Pa)) ; write(not_swi) ), nl,
    thread_self(T), writeq(thread_self(T)), nl,
    last([a, b, c], L), writeq(last(L)), nl,
    sum_list([1, 2, 3], S), writeq(sum(S)), nl.
:- initialization(main, main).
