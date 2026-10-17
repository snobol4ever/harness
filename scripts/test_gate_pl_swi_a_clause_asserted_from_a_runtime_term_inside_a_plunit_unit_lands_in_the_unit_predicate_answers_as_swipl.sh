#!/usr/bin/env bash
# test_gate_pl_swi_a_clause_asserted_from_a_runtime_term_inside_a_plunit_unit_lands_in_the_unit_predicate_answers_as_swipl.sh -- A CLAUSE ASSERTED FROM A RUNTIME TERM INSIDE A plunit UNIT LANDS IN THE UNIT'S OWN PREDICATE (hq_prolog 2026-10-15, row
# prolog-asserting-a-long-conjunction-...-big-clause; swi_tests db/test_db res_compiler:big_clause).  The module flattener (prolog_lower.c pl_module_flatten) renames a
# predicate a unit defines or declares dynamic to plunit_<Unit>:name and qualifies every goal that names it, but assertz(C) / retract(C) / clause(H, B) whose
# argument is a VARIABLE bound at run time named the bare name: the clause went to tmp/2, the unit's call read plunit_u:tmp/2, and the call saw nothing (the SWI
# test_big_clause builds its clause from link_clause/4 and asserts the variable).  THE CURE: pl_mod_rt_clause rewrites such a goal inside a flattened module to
# '$mctx_assertz'(M1, M2, C) (assert, asserta, assertz in both arities, retract, retractall, clause) and the prelude's '$mctx_head' renames the head to M1:name or M2:name
# when that predicate is declared or defined, else leaves it - the context-module semantics of swipl for the unit's goals.
# THE ARM: the unit below runs under swipl -g run_tests (the W: lines its bodies print) and under SCRIP's plunit shim (corpus/tests/prolog/plunit.pl) in mode 3 and mode 4.
# RED BEFORE (the parent): tests a to d print nothing (their calls found no clause); test i is the core/test_arith bigint:clause_1 shape (clause/3 on a head the call
# renamed to plunit_mq:cnt answers the renamed head, so the unit's clause comparison fails).
# rc=0 both modes print swipl's lines - rc=1 a divergence - rc=2 REFUSAL (no swipl, no build, no shim).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_swi_a_clause_asserted_from_a_runtime_term_inside_a_plunit_unit_lands_in_the_unit_predicate_answers_as_swipl
refuse() { echo "REFUSED(2) [$GATE]: $*"; exit 2; }
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PLUNIT="${S4E_CORPUS:-$ROOT/corpus}/tests/prolog/plunit.pl"
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -f "$PLUNIT" ] || refuse "no plunit shim at $PLUNIT"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/u.pl" <<'PL'
:- use_module(library(plunit)).
:- begin_tests(mq).
:- dynamic tmp/2, cnt/1.
test(a) :- C1 = tmp(5, 6), assertz(C1), tmp(5, X1), format("W:~q~n", [X1]).
test(b) :- C2 = (tmp(7, V) :- V = 8), assertz(C2), tmp(7, X2), format("W:~q~n", [X2]).
test(c) :- C3 = tmp(9, 10), asserta(C3, Ref), tmp(9, Y3), erase(Ref), findall(Z, tmp(9, Z), L3), format("W:~q ~q~n", [Y3, L3]).
test(d) :- C4 = tmp(5, 6), retract(C4), findall(X-Y, tmp(X, Y), L4), format("W:~q~n", [L4]).
test(e) :- H5 = tmp(7, _), retractall(H5), findall(X-Y, tmp(X, Y), L5), format("W:~q~n", [L5]).
test(f) :- H6 = cnt(_), assertz(cnt(1)), clause(H6, B6), format("W:~q~n", [B6]).
test(g) :- forall(member(N, [1, 2, 3]), (C7 = cnt(N), assertz(C7))), findall(M, cnt(M), L7), format("W:~q~n", [L7]).
test(h) :- H = cnt(1), ( retract(H) -> format("W:retracted~n") ; format("W:none~n") ), findall(M, cnt(M), L), format("W:~q~n", [L]).
test(i) :- Cl = (cnt(77) :- true), assertz(Cl, R), clause(H, B, R), erase(R), format("W:~q ~q ~q~n", [H, B, H =@= cnt(77)]).
:- end_tests(mq).
PL
printf 'main :- run_tests.\n:- initialization(main).\n' > "$D/wrap.pl"
( cd "$D" && timeout -k 5 30 swipl -q -g run_tests -t halt u.pl < /dev/null 2> /dev/null | grep '^W:' > want )
[ -s "$D/want" ] || refuse "swipl printed no W: line for the witness"
( cd "$D" && timeout -k 5 60 "$B/scrip" --run "$PLUNIT" u.pl wrap.pl < /dev/null 2> m3.err | grep '^W:' > m3 )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o u.s "$PLUNIT" u.pl wrap.pl < /dev/null 2> m4.err && gcc -no-pie u.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o u 2>> m4.err && timeout -k 5 60 ./u < /dev/null 2>> m4.err | grep '^W:' > m4 )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as swipl"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -10 | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $GATE"
exit "$red"
