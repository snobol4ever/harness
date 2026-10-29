#!/usr/bin/env bash
# test_gate_pl_max_arity_is_the_functor_tables_int_bound.sh -- the max_arity flag reads 2147483647, the functor table's own
# int bound, and every term-building builtin builds up to it: no fixed cap of 1024 (cfo 2026-10-08, row prolog-max-arity-
# is-a-fixed-cap-of-1024-where-swipl-reads-unbounded-and-builds-an-arity-2000-term; the ceo's ruling CEO-1540, reading B).
#
# WHAT THIS PINS, m3 and m4. The flag and its enumeration read 2147483647 (PROLOG_MAX_ARITY = INT_MAX, rt/prolog_atom.h);
# functor/3 builds arity 2000 and 5000, =../2 builds and takes apart arity 3000 and 5000, copy_term/2 copies arity 4000;
# one past the bound, as an integer and as a bignum, is representation_error(max_arity) from functor/3 and abolish/1 (the
# INRIA goals functor#229, functor-bis#247, abolish#3); set_prolog_flag(max_arity, _) is permission_error(modify, flag,
# max_arity); abolish(foo/2000) succeeds.
#
# THE REF IS THE RULING'S, NOT AN ORACLE'S. swipl 9 builds the same terms but reads the flag as the atom unbounded (so its
# A + 1 is a type_error), names its bignum error size_t, and refuses abolish(foo/2000) with its own max_procedure_arity;
# CEO-1540 chose the integer bound so the INRIA goals stay green, and ISO states the representation and permission errors
# this ref carries.
#
# RED BEFORE (SCRIP 82db2d5aa, the parent): the flag reads 1024 and functor/3 at 2000, =../2 at 3000 and 5000 and
# copy_term at 4000 raise representation_error(max_arity). GREEN AFTER: m3 and m4 byte-identical to the ref.
#
# Usage: bash ../harness/scripts/test_gate_pl_max_arity_is_the_functor_tables_int_bound.sh
set -uo pipefail
GATE_NAME=test_gate_pl_max_arity_is_the_functor_tables_int_bound
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pl" <<'PL'
:- initialization(main).
t(N, G) :- write(N), write(': '), catch((G -> true ; write(failed)), error(E, _), (write(caught(E)))), nl.
main :-
    t(flag, (current_prolog_flag(max_arity, A), write(A))),
    t(enum, (current_prolog_flag(F, V), F == max_arity, write(F-V))),
    t(functor2000, (functor(T, f, 2000), arg(2000, T, X), (var(X) -> write(ok) ; write(no)))),
    t(univ3000, (numlist(1, 3000, L), T3 =.. [g|L], functor(T3, _, N3), arg(3000, T3, Y), write(N3/Y))),
    t(functor5000_univ, (functor(T5, h, 5000), T5 =.. [_|As], length(As, N5), write(N5))),
    t(copy_term4000, (functor(T6, k, 4000), copy_term(T6, T7), functor(T7, _, N7), write(N7))),
    t(functor_max_plus_1, (current_prolog_flag(max_arity, M), M1 is M + 1, functor(_, foo, M1))),
    t(functor_bignum, functor(_, f, 100000000000000000000)),
    t(abolish_max_plus_1, (current_prolog_flag(max_arity, M2), M3 is M2 + 1, abolish(foo/M3))),
    t(set_flag, set_prolog_flag(max_arity, 40)),
    t(abolish2000, (abolish(foo/2000), write(ok))),
    halt.
PL
cat > "$T/ref" <<'REF'
flag: 2147483647
enum: max_arity-2147483647
functor2000: ok
univ3000: 3000/3000
functor5000_univ: 5000
copy_term4000: 4000
functor_max_plus_1: caught(representation_error(max_arity))
functor_bignum: caught(representation_error(max_arity))
abolish_max_plus_1: caught(representation_error(max_arity))
set_flag: caught(permission_error(modify,flag,max_arity))
abolish2000: ok
REF
fail=0
( cd "$T" && timeout -k 5 30 "$SCRIP" w.pl < /dev/null > m3.out 2>&1 ); rc3=$?
if cmp -s "$T/m3.out" "$T/ref"; then echo "  ok   (m3) $(wc -l < "$T/ref") rows answer as CEO-1540 rules"; else echo "  FAIL (m3) rc=$rc3, first difference:"; diff "$T/ref" "$T/m3.out" | head -6 | sed 's/^/         /'; fail=1; fi
if ( cd "$T" && "$SCRIP" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 && gcc -o w w.s -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 30 ./w < /dev/null > m4.out 2>&1 ); rc4=$?
    if cmp -s "$T/m4.out" "$T/ref"; then echo "  ok   (m4) the same, from the standalone build"; else echo "  FAIL (m4) rc=$rc4, first difference:"; diff "$T/ref" "$T/m4.out" | head -6 | sed 's/^/         /'; fail=1; fi
else echo "  FAIL (m4) the witness did not compile or link in mode 4"; fail=1; fi
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: max_arity is the functor table's int bound, m3 and m4"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1
