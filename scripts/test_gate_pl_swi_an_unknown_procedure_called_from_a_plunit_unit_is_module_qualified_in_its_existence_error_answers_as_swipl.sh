#!/usr/bin/env bash
# test_gate_pl_swi_an_unknown_procedure_called_from_a_plunit_unit_is_module_qualified_in_its_existence_error_answers_as_swipl.sh -- AN UNKNOWN PROCEDURE CALLED FROM A plunit UNIT NAMES ITS MODULE IN THE existence_error (hq_prolog 2026-10-15, row prolog-swi-core-test-call-...-ceo-1664;
# core/test_call callN:qn8, callN:an8 and no_autoload:unknown expect existence_error(procedure, M:name/arity)).  swipl reports the module the goal was called from when
# it is not user: a unit's goal reads plunit_<Unit>:name/Arity, call(Q:name, ...) reads Q:name/Arity, a goal inside a user-module helper stays name/Arity.  SCRIP's module
# emulation (pl_module_flatten) has no module at run time, so (1) pl_user_call in lower_prolog.c wraps a call it cannot resolve inside a unit's clause (the key starts
# plunit_) as '$mctx_call'(Unit, Goal), an explicit M:G qualifier replacing the unit (user: replacing it by nothing); (2) pl_mod_var_call in prolog_lower.c wraps a
# variable goal that is a conjunct of a unit clause the same way; (3) the mctx library's '$mctx_call'/2 catches existence_error(procedure, N/A) and rethrows M:N/A only
# when N/A is the functor of the goal or of one of its control-construct leaves, so an error from a deeper call in a user helper passes unchanged.
# THE ARM: the unit below runs under swipl -g run_tests (the W: lines its bodies print) and under SCRIP's plunit shim (corpus/tests/prolog/plunit.pl) in mode 3 and mode 4.
# RED BEFORE (the parent): W: lines 1 to 3, 7 and 8 print the bare name/arity.
# rc=0 both modes print swipl's lines - rc=1 a divergence - rc=2 REFUSAL (no swipl, no build, no shim).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_swi_an_unknown_procedure_called_from_a_plunit_unit_is_module_qualified_in_its_existence_error_answers_as_swipl
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
helper_deep :- undefined_deep(1).
helper_ok(X) :- X = 1.
:- begin_tests(uq).
p_a :- Goal = call(does_not_exist, a, b, c), Goal.
p_b :- Goal = call(call8:does_not_exist, a, b, c, d), Goal.
p_c :- this_should_not_be_defined(_).
p_d :- helper_deep.
p_e :- call(user:nonexistent_u).
p_g :- G = helper_ok(Y), G, format("W:~q~n", [Y]).
p_h :- Goal = undefined_in_g(1), Goal.
p_i :- Goal = (helper_ok(Z), write_unknown(Z)), Goal.
p_j :- Goal = helper_deep, Goal.
q(G) :- catch(G, error(existence_error(procedure, PI), _), format("W:~q~n", [PI])).
test(a) :- q(p_a).
test(b) :- q(p_b).
test(c) :- q(p_c).
test(d) :- q(p_d).
test(e) :- q(p_e).
test(g) :- q(p_g).
test(h) :- q(p_h).
test(i) :- q(p_i).
test(j) :- q(p_j).
:- end_tests(uq).
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
