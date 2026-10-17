#!/usr/bin/env bash
# test_gate_pl_retract_logical_view_flags_gensym_and_swi_atom_concat_answer_as_swipl.sh -- retract/1 MATCHES A CLAUSE TERM (H :- B) AND A
# MODULE-QUALIFIED HEAD ON THE RUN-TIME ROAD, KEEPS THE LOGICAL UPDATE VIEW, flag/3 get_flag/2 set_flag/2 with_mutex/2 AND library(gensym)
# EXIST, AND IN THE SWI DIALECT atom_concat/3 TAKES A NUMBER, AS swipl ANSWERS (cfo 2026-10-14, row
# prolog-swi-db-test-db-every-case-agrees-with-swipl-in-both-modes-ceo-1664, CEO-1698).
#
# SWI's db/test_db.pl read 6/20 graded in both modes. The cures: (1) a retract/1 whose argument is not a literal clause (a variable,
# or anything called through call/1 -- every plunit case body) built the target (A :- true) at compile time, so retract((foo(X) :- true))
# and retract(foo(1) :- B) never matched; the lowerer (src/lower/lower_prolog.c) now calls the base-prelude '$retract_target'/2 first,
# which keeps a (H :- B) argument, wraps anything else as (C :- true), and maps a M: qualifier through '$mod_head'/3 onto the
# predicate a module or unit renamed. (2) The db enumeration already yields every clause visible at the generation it took (ISO's
# logical update view), but '$db_erase' failed on a clause a later goal had erased meanwhile, so retract skipped it; it succeeds now
# (rt_pl_db_slot_erased, unification.c). gprolog 1.6.0 answers both update-view shapes as swipl. (3) flag/3, get_flag/2, set_flag/2
# (one nb_setval cell per key) and with_mutex/2 (once/1: SCRIP has no threads) are base-prelude predicates; swipl's library(gensym) is
# vendored (src/parsers/prolog/prelude/gensym.pl, byte-identical; one SOURCE_EDITS line builds the symbol with atomic_list_concat/2);
# a helper erase/1 needs is now selected when a LIBRARY's clause calls erase. (4) In the SWI dialect atom_concat/3 takes a number and
# names a compound type_error(atomic, T); outside it ISO's type_error(atom, T) stands. NOT HERE: the threads flag (SCRIP answers false,
# swipl true), max_procedure_arity (swipl's 1024 limit; SCRIP has none), and a 60000-goal asserted clause (big_clause: the run-time
# compile road is quadratic and recurses once per conjunct).
#
# THE ARMS: two programs (a.pl with no module, b.pl a module file, the SWI dialect), twenty-six properties, stdout cut against swipl in
# this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent 58d8ee54e rebuilt: 22 of 26 lines differ in both modes; with the
# cure 26 of 26 as swipl.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~6 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_retract_logical_view_flags_gensym_and_swi_atom_concat_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/a.pl" <<'PL'
:- dynamic foo/1, insect/1, icopy/1.
:- initialization(main).
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = E), writeq(N-R), nl.
main :- t(retract_fact, (assert(foo(1)), retract(foo(X0)), X0 == 1)), retractall(foo(_)),
    G1 = retract((foo(X1) :- true)), t(retract_fact_as_rule, (assert(foo(1)), call(G1), X1 == 1)), retractall(foo(_)),
    G2 = retract((foo(1) :- B2)), t(retract_open_body, (assert((foo(A2) :- bar(A2))), call(G2), B2 == bar(1))), retractall(foo(_)),
    G3 = retract((foo(1) :- bar(2))), t(retract_body_mismatch, (assert((foo(A3) :- bar(A3))), \+ call(G3))), retractall(foo(_)),
    t(retract_var_module_head, (assert((foo(1) :- bar(a))), context_module(M), G4 = retract((M:foo(X4) :- bar(A4))), call(G4), X4-A4 == 1-a)), retractall(foo(_)),
    t(retract_qualified_clause, (assert((foo(1) :- bar(a))), M5 = user, G5 = retract(M5:(foo(X5) :- bar(_))), call(G5), X5 == 1)), retractall(foo(_)),
    t(update_view_inner_retract, (assertz(insect(ant)), assertz(insect(bee)), ( retract(insect(I)), assertz(icopy(I)), retract(insect(bee)), fail ; findall(J, retract(icopy(J)), L) ), L == [ant,bee])),
    t(update_view_retract_ahead, (assertz(insect(a)), assertz(insect(b)), assertz(insect(c)), findall(X, (retract(insect(X)), (X == a -> retract(insect(c)) ; true)), L2), L2 == [a,b,c])),
    t(retract_var, retract(_)),
    t(flag_count, (flag(k, O, O+1), flag(k, O1, O1*10), get_flag(k, V), [O, O1, V] == [0, 1, 10])),
    t(flag_atom_value, (flag(j, _, foo), get_flag(j, J1), J1 == foo)), t(flag_compound_key, (flag(f(1), A, 5), get_flag(f(1), B), A-B == 0-5)),
    t(set_flag, (set_flag(k, 3), get_flag(k, K), K == 3)), t(flag_old_mismatch_keeps, (\+ flag(k, 99, 1), get_flag(k, K2), K2 == 3)),
    t(get_flag_unset, (get_flag(nosuch, U), U == 0)), t(with_mutex_once, findall(Y, with_mutex(m, member(Y, [1,2])), [1])),
    t(gensym, (gensym(a, S1), gensym(a, S2), gensym(b, S3), [S1,S2,S3] == [a1,a2,b1])), t(reset_gensym_1, (reset_gensym(a), gensym(a, S4), S4 == a1)),
    t(reset_gensym_0, (reset_gensym, gensym(b, S5), S5 == b1)).
PL
cat > "$D/b.pl" <<'PL'
:- module(b, []).
:- initialization(main).
t(N, G) :- catch((G -> R = yes ; R = no), error(E, _), R = E), writeq(N-R), nl.
main :- t(int_right, (atom_concat(a, 1, X), X == a1)), t(float_left, (atom_concat(1.5, b, Y), Y == '1.5b')), G = atom_concat(a, 2, Z), t(called, (call(G), Z == a2)),
    t(split_number, (findall(P+Q, atom_concat(P, Q, 12), L), L == [''+'12', '1'+'2', '12'+''])), t(compound_whole, atom_concat(_, _, f(x))), t(compound_part, atom_concat(a, f(1), _)),
    t(plain_atoms, (atom_concat(X5, b, ab), X5 == a)).
PL
want="$(cd "$D" && { timeout -k 5 20 "$SW" -q a.pl -t halt < /dev/null 2>/dev/null; timeout -k 5 20 "$SW" -q b.pl -t halt < /dev/null 2>/dev/null; } | grep .)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 26 ] || refuse "swipl did not answer the twenty-six properties: [$want]"
for p in a b; do
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o $p.s $p.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile of $p.pl failed"
    ( cd "$D" && gcc -m64 -no-pie $p.s -o $p.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link of $p.pl failed"
done
red=0
arm() {
    local label="$1" got n
    if [ "$label" = m3 ]; then got="$(cd "$D" && { timeout -k 5 20 "$B/scrip" --run a.pl < /dev/null 2>/dev/null; timeout -k 5 20 "$B/scrip" --run b.pl < /dev/null 2>/dev/null; } | grep .)"
    else got="$(cd "$D" && { timeout -k 5 20 ./a.bin < /dev/null 2>/dev/null; timeout -k 5 20 ./b.bin < /dev/null 2>/dev/null; } | grep .)"; fi
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^>')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 26 of 26 lines as swipl"
    else echo "  $label RED: $n of 26 lines differ from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3
arm m4
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
