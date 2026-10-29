#!/usr/bin/env bash
# test_gate_pl_ssu_rules_in_a_module_or_unit_and_their_no_match_error_answer_as_swipl.sh -- AN SSU (=>) RULE IN A MODULE FILE OR A plunit UNIT
# RUNS, AND ITS NO-MATCH ERROR CARRIES THE MODULE AND THE CONTEXT AS swipl's DOES (cfo 2026-10-14, SWI library/test_rbtrees.pl
# sequence#1 and instantiation_visit_2).
#
# THE DEFECT: the module flattener (prolog_lower.c pl_module_flatten) read an SSU clause as a clause whose head is the arrow itself
# (SCRIP keeps Head => Body as one '=>'(Lhs, Body) child), so every SSU rule inside a module file or a begin_tests unit defined a
# predicate named '=>'/2, renamed 'plunit_u:=>'/2: no SSU predicate of a unit or module ever ran (library/test_rbtrees' det
# apply_op/3 fed foldl: sequence#1 read FAIL). The cure reads the head out of the arrow (pl_ssu_head) for the definition pass and
# the rename pass, and renames the guard and body goals like any clause's. Second: pl_ssu_nomatch raised
# existence_error(matching_rule, f(c,_)) with no context; swipl raises existence_error(matching_rule, M:f(c,_)) with context(M:f/2,_)
# (M absent for user): the error now carries both, M taken from the flattened name 'M:f'.
# NOT HERE: a predicate a MODULE FILE or a vendored library EXPORTS keeps its plain name, so its no-match error cannot name the
# module (library(rbtrees)' rb_visit/2: instantiation_visit_2 stays red until the flattener keeps that fact).
#
# THE ARMS: two programs under the plunit shim (a user file with a unit, and a module file with a unit), 17 lines, stdout cut
# against swipl running the same programs with its own library(plunit) in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent 9fdd27fb8
# rebuilt: 12 of 17 lines differ in both modes (every SSU rule of a unit or module is the predicate =>/2 there, and the no-match errors carry
# neither module nor context); with the cure 17 of 17 as swipl in both modes.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no shim, no build).  ~5 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_ssu_rules_in_a_module_or_unit_and_their_no_match_error_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
PLUNIT="${S4E_CORPUS:-$B/../corpus}/tests/prolog/plunit.pl"; [ -f "$PLUNIT" ] || refuse "no plunit shim at $PLUNIT"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w1.pl" <<'PL'
:- use_module(library(plunit)).
f(a, X) => X = 1.
f(b, X) => X = 2.
g(-K, X) => X = K.
h(Y, X), Y == z => X = zz.
h(_, X) => X = other.
:- meta_predicate pt(+, 0, ?).
pt(N, G, X) :- catch((G -> R = ok(X) ; R = no), error(E, C), R = err(E, C)), \+ \+ ( numbervars(N-R, 0, _), write_term(N-R, [quoted(true), numbervars(true)]), nl ).
:- begin_tests(u).
k(a, X) => X = 1.
k(-N, X) => X = N.
m(Y, X), Y == z => X = zz.
m(_, X) => X = other.
test(a) :- pt(user_f, f(a, X1), X1), pt(user_f2, f(b, X2), X2), pt(user_g, g(-a, X3), X3), pt(user_h1, h(z, X4), X4), pt(user_h2, h(q, X5), X5),
           pt(user_nomatch, f(c, _), _), pt(user_unbound, f(_, _), _).
test(b) :- pt(unit_k, k(a, Y1), Y1), pt(unit_k2, k(-b, Y2), Y2), pt(unit_m1, m(z, Y3), Y3), pt(unit_m2, m(q, Y4), Y4), pt(unit_nomatch, k(c, _), _).
:- end_tests(u).
PL
cat > "$D/w2.pl" <<'PL'
:- module(tm, []).
:- use_module(library(plunit)).
f(a, X) => X = 1.
g(-K, X) => X = K.
h(Y, X), Y == z => X = zz.
h(_, X) => X = other.
:- meta_predicate pt(+, 0, ?).
pt(N, G, X) :- catch((G -> R = ok(X) ; R = no), error(E, C), R = err(E, C)), \+ \+ ( numbervars(N-R, 0, _), write_term(N-R, [quoted(true), numbervars(true)]), nl ).
:- begin_tests(u).
test(a) :- pt(mod_f, f(a, X1), X1), pt(mod_g, g(-a, X2), X2), pt(mod_h1, h(z, X3), X3), pt(mod_h2, h(q, X4), X4), pt(mod_nomatch, f(b, _), _).
:- end_tests(u).
PL
printf ':- initialization(run_tests).\n' > "$D/g.pl"
norm() { grep -E '^\.?[a-z_0-9]+-' | sed 's/^\.//'; }
want="$(for w in w1 w2; do (cd "$D" && timeout -k 5 20 "$SW" -q -g run_tests -t halt $w.pl < /dev/null 2>/dev/null | norm); done)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 17 ] || refuse "swipl did not answer the seventeen lines: [$want]"
m4ok=1   # a program SCRIP refuses to compile is this gate's red, never a refusal
for w in w1 w2; do
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=$w.s "$PLUNIT" $w.pl g.pl < /dev/null > /dev/null 2>&1 && [ -s $w.s ] \
      && gcc -m64 -no-pie $w.s -o $w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
done
red=0
arm() {
    local label="$1" got n; shift
    got="$(for w in w1 w2; do (cd "$D" && "$@" $w | norm); done)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 17 of 17 lines as swipl"
    else echo "  $label RED: $n of 17 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
m3run() { timeout -k 5 30 "$B/scrip" --run "$PLUNIT" "$1.pl" g.pl < /dev/null 2>/dev/null; }
m4run() { timeout -k 5 30 "./$1.bin" < /dev/null 2>/dev/null; }
arm m3 m3run
if [ "$m4ok" = 1 ]; then arm m4 m4run; else echo "  m4 RED: a program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
