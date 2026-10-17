#!/usr/bin/env bash
# test_gate_pl_swi_shim_grades_all_by_each_plunit_comparison.sh -- the plunit shim (corpus/tests/prolog/plunit.pl) grades a test
# carrying all(Template Cmp Expected) for each comparison swipl's plunit takes, ==, =:=, = and =@=, element by element as plunit's
# cmp_list/3 does (the coo, 2026-10-11, on hq_prolog's report: library/test_yall.pl disjunction and free read "no verdict from the
# shim" whatever the program did, because pj_do_all had a clause for == alone). RED BEFORE, measured on SCRIP 765ce1154 with the
# old shim: the witness below read four of its six all/1 tests "no verdict from the shim"; library/test_yall.pl hit 24 of 42 and
# core/test_bips.pl 38 of 46 in util_swi_match.py, 25 and 39 after (yall_tests:disjunction, length:gen_unbound).
# AND the bare form (hq_prolog's report, 2026-10-11): plunit's shorthand test(Name, A Cmp B) means true(A Cmp B) for the same four
# comparisons (swipl's plunit.pl expand_option/2); the shim had no clause for it, so a bare option passed whenever the body succeeded,
# whatever the value -- 733 test heads in 76 swi_tests files. RED BEFORE on the old shim: bare_wrong and listed_wrong read pass.
# ARMS: (P) the premise -- swipl's own plunit runs the witness and fails exactly the test named wrong, so the verdicts wanted here
# are the oracle's; (W) both modes -- the witness through the shim prints exactly those verdicts, one line per test.
set -u
GATE_NAME=test_gate_pl_swi_shim_grades_all_by_each_plunit_comparison
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
CORPUS="${S4E_CORPUS:-$ROOT/corpus}"
PLUNIT="$CORPUS/tests/prolog/plunit.pl"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"; RT="${RT_DIR:-$HERE/../../SCRIP/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -f "$PLUNIT" ] || refuse "no shim at $PLUNIT"
[ -x "$SCRIP" ] || refuse "no scrip binary -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unloadable"
SWIPL="$(swipl_bin 2>/dev/null)"; [ -x "$SWIPL" ] || refuse "no swipl oracle"
MODES="${PL_RUNG_MODES:-m3,m4}"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'main :- run_tests.\n:- initialization(main).\n' > "$T/wrap.pl"
cat > "$T/w.pl" <<'EOP'
:- begin_tests(al).
p(1). p(2).
q(1,a). q(2,b).
test(unify, all(X = [1,2])) :- p(X).
test(pair, all(A-B = [1-a,2-b])) :- q(A,B).
test(ident, all(X == [1,2])) :- p(X).
test(variant, all(X =@= [f(_),f(_)])) :- p(_), X = f(_).
test(arith, all(X =:= [1.0,2.0])) :- p(X).
test(wrong, all(X = [1])) :- p(X).
test(after) :- true.
test(bare_ident, X == 2) :- X = 2.
test(bare_wrong, X == 2) :- X = 1.
test(bare_arith, X =:= 2.0) :- X = 2.
test(bare_unify, X = f(_)) :- X = f(1).
test(bare_variant, X =@= f(_)) :- X = f(_).
test(listed_wrong, [X == 3]) :- X = 1.
:- end_tests(al).
EOP
want="$(printf '%s\n' '  pass: al:unify' '  pass: al:pair' '  pass: al:ident' '  pass: al:variant' '  pass: al:arith' \
    '  FAIL: al:wrong  (all mismatch)' '  pass: al:after' '  pass: al:bare_ident' '  FAIL: al:bare_wrong  (true check failed)' \
    '  pass: al:bare_arith' '  pass: al:bare_unify' '  pass: al:bare_variant' '  FAIL: al:listed_wrong  (true check failed)')"
red=0; total=1
oracle="$(cd "$T" && timeout -k 5 60 "$SWIPL" -q -g run_tests -t halt w.pl 2>&1)"
failed="$(printf '%s\n' "$oracle" | sed -n 's/^[[:space:]]*test \([a-z_]*\): .*/\1/p' | sort -u | tr '\n' ' ')"
if [ "$failed" = "bare_wrong listed_wrong wrong " ]; then echo "  ok  premise: swipl's plunit fails exactly bare_wrong, listed_wrong and wrong on the witness"
else echo "  RED premise: swipl's plunit failed [${failed}], want [bare_wrong listed_wrong wrong] -- the wanted verdicts are no longer the oracle's"; red=$((red+1)); fi
run() { local mode="$1"
    if [ "$mode" = m4 ]; then timeout -k 5 60 "$SCRIP" --compile "$PLUNIT" "$T/w.pl" "$T/wrap.pl" > "$T/p.s" 2>/dev/null && gcc -no-pie "$T/p.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$T/p" 2>/dev/null && timeout -k 5 60 "$T/p" </dev/null 2>/dev/null
    else timeout -k 5 60 "$SCRIP" --run "$PLUNIT" "$T/w.pl" "$T/wrap.pl" </dev/null 2>/dev/null; fi; }
for mode in ${MODES//,/ }; do
    total=$((total+1))
    got="$(run "$mode" | grep -E '^\s+(pass|FAIL|skip):')"
    if [ "$got" = "$want" ]; then echo "  ok  witness $mode: ==, =:=, =, =@= graded in all/1 and bare; a wrong all/1 is an all mismatch, a wrong bare comparison a true-check FAIL"
    else echo "  RED witness $mode: got [$(printf '%s' "$got" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
