#!/usr/bin/env bash
# test_gate_pl_a_dict_expression_in_a_plunit_test_body_is_evaluated_inside_the_test_as_swipl.sh -- SWI'S FUNCTIONAL NOTATION
# IN A plunit TEST BODY IS EVALUATED WHEN THE TEST RUNS, INSIDE IT, AS swipl EXPANDS IT (cfo 2026-10-14, row
# prolog-swi-core-test-dict-every-case-agrees-with-swipl-in-both-modes-ceo-1709).
#
# SWI's core/test_dict.pl read 0/93: no case ran. The SWI runner grades a file through the plunit shim, which keeps each
# test as a pj_test(Unit, Name, Options, Body) fact whose Body is the test's goal held as data. lower_prolog.c's dict rewrite
# (pl_dict_clause) treated every head argument of a clause as data and hoisted each Dict.key it found there in front of the
# clause -- so a test body holding [a(x):1, b:2].a made the pj_test FACT raise when the shim enumerated the tests, outside every
# catch, and the whole run died on its first such test. The cure expands pj_test/4's Body argument as a goal (pl_dot_goal, the
# expansion a clause body gets), so each evaluation stays inside the test, before the subgoal that uses it, as swipl's
# expansion of the test clause places it. test_dict 0/93 -> 61/93 in mode 3.
# NOT HERE: the error swipl raises for a list that is not a valid dict (type_error('dict-key', a(x)); SCRIP raises
# type_error(dict, List)), select_dict/3, b_set_dict/3, nb_set_dict/3, :< and >:<, and dict-method definitions -- the row's NEXT.
#
# THE ARMS: one plunit unit, four lines (a get, a put, a nested get, and a test that runs after one whose body raises), stdout cut
# against swipl with its own library(plunit) in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent a572de3f8
# rebuilt: 4 of 4 lines missing in both modes (the run dies enumerating the tests); with the cure 4 of 4 as swipl in both.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no shim, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_a_dict_expression_in_a_plunit_test_body_is_evaluated_inside_the_test_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
PLUNIT="${S4E_CORPUS:-$B/../corpus}/tests/prolog/plunit.pl"; [ -f "$PLUNIT" ] || refuse "no plunit shim at $PLUNIT"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(plunit)).
:- begin_tests(dot_in_body).
test(get) :- X = _{k:1}.k, writeq(get-X), nl.
test(put) :- D = _{a:1}.put(b, 2), get_dict(b, D, V), writeq(put-V), nl.
test(raise, error(_)) :- X = [a(x):1, b:2].a, writeq(never(X)), nl.
test(after) :- writeq(after-ran), nl.
test(nested) :- D = _{p:_{q:7}}, X = D.p.q, writeq(nested-X), nl.
:- end_tests(dot_in_body).
PL
printf ':- initialization(run_tests).\n' > "$D/g.pl"
want="$(cd "$D" && timeout -k 5 20 "$SW" -q -g run_tests -t halt w.pl < /dev/null 2>/dev/null | grep -E '^[a-z_]+-')"
[ "$(printf '%s\n' "$want" | grep -c .)" = 4 ] || refuse "swipl did not answer the four lines: [$want]"
m4ok=1   # a program SCRIP refuses to compile is this gate's red, never a refusal
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s "$PLUNIT" w.pl g.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep -E '^[a-z_]+-')"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 4 of 4 lines as swipl"
    else echo "  $label RED: $n of 4 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run "$PLUNIT" w.pl g.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
