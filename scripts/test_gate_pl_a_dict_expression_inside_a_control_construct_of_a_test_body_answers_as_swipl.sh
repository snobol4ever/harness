#!/usr/bin/env bash
# test_gate_pl_a_dict_expression_inside_a_control_construct_of_a_test_body_answers_as_swipl.sh -- A Dict.key INSIDE A CONTROL CONSTRUCT
# OR A bagof/setof GOAL OF A plunit TEST BODY ANSWERS AS swipl (cfo 2026-10-14, row
# prolog-swi-core-test-dict-every-case-agrees-with-swipl-in-both-modes-ceo-1709: test_dict expand_functions:bagof#1).
#
# 7ea7b91fe expands the shim's pj_test/4 Body as a goal (pl_dot_goal), and pl_dot_goal expanded A = M.a to
# '$dict_eval'(M, a, V), A = V. Held as data in a test body, a bagof/setof goal runs at run time, where that fresh V is a FREE
# variable: bagof(A, M^(dict(M), A = M.a), As) grouped by V and answered [1] then [3]. The cure (lower_prolog.c pl_dot_goal): a =/2
# goal with a Dict.key on exactly one side evaluates straight into the other side ('$dict_eval'(M, a, A)), as swipl's expansion of
# X = Dict.key does -- no fresh variable. The other four arms (forall, negation, if-then-else, a disjunction inside findall) read
# green on the parent too: the existing meta templates already expand those constructs child by child; they guard that a
# Dict.key in each still lands after the subgoal that binds its dict.
#
# THE ARMS: one plunit unit, six lines, stdout cut against swipl with its own library(plunit) in this run, mode 3 and mode 4.
# FAIL-ONCE, measured on the parent 585b73413 rebuilt: 2 of 6 lines differ in both modes (bagof-[1] and setof-[1] where swipl
# answers [1,3]); with the cure 6 of 6 as swipl in both modes.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no shim, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_a_dict_expression_inside_a_control_construct_of_a_test_body_answers_as_swipl
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
dict(_{a:1}).
dict(_{a:3}).
:- begin_tests(dot_in_control).
test(bagof) :- bagof(A, M^(dict(M), A = M.a), As), writeq(bagof-As), nl.
test(setof) :- setof(A, M^(dict(M), A = M.a), S), writeq(setof-S), nl.
test(forall) :- forall(dict(M), (X = M.a, X > 0)), writeq(forall-ok), nl.
test(negation) :- \+ (dict(M), M.a > 5), writeq(negation-ok), nl.
test(ite) :- ( dict(M), M.a =:= 3 -> writeq(ite-found) ; writeq(ite-none) ), nl.
test(disj) :- findall(V, (dict(M), (M.a =:= 1 -> V = one ; V = M.a)), Vs), writeq(disj-Vs), nl.
:- end_tests(dot_in_control).
PL
printf ':- initialization(run_tests).\n' > "$D/g.pl"
want="$(cd "$D" && timeout -k 5 20 "$SW" -q -g run_tests -t halt w.pl < /dev/null 2>/dev/null | grep -E '^[a-z_]+-')"
[ "$(printf '%s\n' "$want" | grep -c .)" = 6 ] || refuse "swipl did not answer the six lines: [$want]"
m4ok=1   # a program SCRIP refuses to compile is this gate's red, never a refusal
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s "$PLUNIT" w.pl g.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep -E '^[a-z_]+-')"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 6 of 6 lines as swipl"
    else echo "  $label RED: $n of 6 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run "$PLUNIT" w.pl g.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
