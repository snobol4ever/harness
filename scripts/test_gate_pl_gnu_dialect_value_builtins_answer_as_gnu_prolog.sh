#!/usr/bin/env bash
# test_gate_pl_gnu_dialect_value_builtins_answer_as_gnu_prolog.sh -- the GNU Prolog value builtins GNU's own compiler
# pl2wam executes answer as GNU Prolog 1.6.0 does, and read_term skips a % comment inside a clause (cto 2026-09-27,
# CTO-188, the pl2wam demo row prolog-demo-gnus-wam-compiler-pl2wam-...-ceo-1312).
#
# WHAT THIS PINS. (1) In-place sort/1, msort/1 and keysort/1 (GNU: the list is rewritten in its own cells, not undone
# on backtracking, duplicates removed by shortening it); their ISO errors are graded by formal only. (2) The stream
# positions -- last_read_start_line_column/2, line_count/2, line_position/2, stream_line_column/3 and
# character_count/2 -- over a file whose second clause carries "(e.g. this)." inside a % comment. (3) The reader: a %
# comment inside a clause is layout; before the cure SCRIP's term-text reader skipped % only before a term started,
# so the "g. " in the comment ended the clause and read_term raised syntax_error (GNU's Pl2Wam/indexing.pl line 147).
# (4) g_assign/2 and g_read/2 (copy on store, 0 when unset), list/1, memberchk/2, decompose_file_name/4,
# is_relative_file_name/1, prolog_file_name/2, absolute_file_name/2 and GNU's aux-name services.
#
# THE REF IS GNU PROLOG 1.6.0's OUTPUT (the instrumented fork's pristine build), cut when the gate was written; the
# gate re-cuts it when that gprolog is on the box and refuses rc=2 on disagreement. Variable print names differ
# between the two systems, so every printed term is ground or numbervar'd.
#
# RED BEFORE (measured on SCRIP 964982d54 this sitting): every builtin above raised existence_error(procedure, ...)
# and reading Pl2Wam/indexing.pl raised syntax_error(cannot_start_term) at line 147. GREEN AFTER: m3 and m4
# byte-identical to the ref.
#
# Usage: bash ../harness/scripts/test_gate_pl_gnu_dialect_value_builtins_answer_as_gnu_prolog.sh
set -uo pipefail
GATE_NAME=test_gate_pl_gnu_dialect_value_builtins_answer_as_gnu_prolog
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
GP_BIN=/home/resources/gprolog-mon/pristine/bin
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'alpha(1).\n  beta(X) :- X = 2, %% a comment (e.g. this).\n    true.\ngamma :- write(a%%x\n), nl.\n' > "$T/src.pl"
cat > "$T/w.pl" <<'PL'
:- initialization(main).
formal(error(F, _), F) :- !.
formal(B, B).
t(Name, G) :- write(Name), write(': '), catch((G -> true ; write(failed)), E, (formal(E, F), write(caught(F)))), nl.
rd(S) :- read_term(S, T, []), ( T == end_of_file -> true ; last_read_start_line_column(L, C), line_count(S, N), line_position(S, P), stream_line_column(S, L2, C2),
    \+ \+ (numbervars(T, 0, _), writeq(T-start(L, C)-after(N, P, L2, C2))), nl, rd(S) ).
main :-
    t(sort1, (L1 = [b, a, c, b, f(y)], sort(L1), write(L1))),
    t(sort1_not_undone, (L2 = [c, a], ( sort(L2), fail ; true ), write(L2))),
    t(msort1, (L3 = [b, a, b], msort(L3), write(L3))),
    t(keysort1_stable, (L4 = [b-1, a-2, b-0, a-1], keysort(L4), write(L4))),
    t(sort1_empty, (L5 = [], sort(L5), write(L5))),
    t(sort1_partial, sort([a|_])), t(sort1_not_list, sort(foo)), t(keysort1_not_pair, keysort([a])),
    t(reader, (open('src.pl', read, S), rd(S), character_count(S, CC), write(chars(CC)), close(S))),
    t(g_vars, (g_read(unset_key, U), g_assign(k1, f(Z)), Z = bound, g_read(k1, V), g_assign(k2, 7), g_read(k2, W), V = f(Q), ( var(Q) -> Vs = copied ; Vs = shared ), write([U, Vs, W]))),
    t(list, (list([a, b]), \+ list([a|_]), \+ list(foo), write(ok))),
    t(memberchk, (memberchk(X, [p, q]), write(X))),
    t(decompose, (decompose_file_name('/a/b/c.pl', D, P, Sx), decompose_file_name(abc, D2, P2, S2), writeq([D, P, Sx, D2, P2, S2]))),
    t(relative, (is_relative_file_name('a/b'), \+ is_relative_file_name('/a'), write(ok))),
    t(prolog_file_name, (prolog_file_name(user, F1), prolog_file_name('x.txt', F2), prolog_file_name(src, F3), prolog_file_name(nosuch, F4), writeq([F1, F2, F3, F4]))),
    t(absolute, (absolute_file_name('/a/./b//c/../d', A1), absolute_file_name(user, A2), writeq([A1, A2]))),
    t(aux_names, ('$make_aux_name'(foo, 2, 3, AN), '$aux_name'(AN), '$pred_without_aux'(AN, 9, F, Ar), '$pred_without_aux'(bar, 1, F5, A5), writeq([AN, F, Ar, F5, A5]))),
    halt.
PL
cat > "$T/ref" <<'REF'
sort1: [a,b,c,f(y)]
sort1_not_undone: [a,c]
msort1: [a,b,b]
keysort1_stable: [a-2,a-1,b-1,b-0]
sort1_empty: []
sort1_partial: caught(instantiation_error)
sort1_not_list: caught(type_error(list,foo))
keysort1_not_pair: caught(type_error(pair,a))
reader: alpha(1)-start(1,1)-after(0,9,1,10)
(beta(A):-A=2,true)-start(2,3)-after(2,9,3,10)
(gamma:-write(a),nl)-start(4,1)-after(4,6,5,7)
chars(91)
g_vars: [0,copied,7]
list: ok
memberchk: p
decompose: ['/a/b/',c,'.pl','',abc,'']
relative: ok
prolog_file_name: [user,'x.txt','src.pl','nosuch.pl']
absolute: ['/a/b/d',user]
aux_names: ['$foo/2_$aux3',foo,2,bar,1]
REF
if [ -x "$GP_BIN/gprolog" ]; then
    ( cd "$T" && PATH="$GP_BIN:$PATH" timeout -k 5 30 "$GP_BIN/gprolog" --consult-file w.pl < /dev/null 2>/dev/null | sed -n '/^sort1:/,$p' > gp.out )
    cmp -s "$T/gp.out" "$T/ref" || { echo "⛔ REFUSED(2) [$GATE_NAME]: GNU Prolog 1.6.0 no longer prints the carried ref -- re-cut it from the oracle, never from SCRIP"; exit 2; }
fi
fail=0
( cd "$T" && timeout -k 5 20 "$SCRIP" w.pl < /dev/null > m3.out 2>&1 ); rc3=$?
if cmp -s "$T/m3.out" "$T/ref"; then echo "  ok   (m3) 18 rows answer as GNU Prolog 1.6.0"; else echo "  FAIL (m3) rc=$rc3, first difference:"; diff "$T/ref" "$T/m3.out" | head -6 | sed 's/^/         /'; fail=1; fi
if ( cd "$T" && "$SCRIP" --compile -o w.s w.pl < /dev/null > /dev/null 2>&1 && gcc -o w w.s -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 20 ./w < /dev/null > m4.out 2>&1 ); rc4=$?
    if cmp -s "$T/m4.out" "$T/ref"; then echo "  ok   (m4) the same, from the standalone build"; else echo "  FAIL (m4) rc=$rc4, first difference:"; diff "$T/ref" "$T/m4.out" | head -6 | sed 's/^/         /'; fail=1; fi
else echo "  FAIL (m4) the witness did not compile or link in mode 4"; fail=1; fi
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: m3 and m4 answer as GNU Prolog 1.6.0"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1
