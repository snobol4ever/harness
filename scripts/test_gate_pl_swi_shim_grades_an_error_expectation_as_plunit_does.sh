#!/usr/bin/env bash
# test_gate_pl_swi_shim_grades_an_error_expectation_as_plunit_does.sh -- the plunit shim (corpus/tests/prolog/plunit.pl)
# grades a case declared error(E) as plunit does: (A) a ball that is NOT error(_,_) is that case's FAIL and the run carries on (hq_prolog to
# the coo, 2026-10-14 13:2x); (B) the case passes only when E SUBSUMES the actual formal, never on a shared functor (the cfo's FINDING of
# 13:4x: SWI core/test_dict dict_create:convert expects type_error('dict-key', a(x)), SCRIP raised type_error(dict, ...), and the shim's
# functor-only match printed pass -- a false PASS for every case whose expected error shares a functor with a wrong actual one).
# (A), MEASURED: THE DEFECT, MEASURED: pj_do_error/4 ran catch(Goal, error(Act,_), ...), so the ball
# escaped the shim, the run died (rc 2, "goal raised exception: b") and every later case of the file went ungraded -- SWI core/test_call
# catch:urgent (freeze(E, throw(b)) under error(instantiation_error)) read "oracle FAIL / no verdict from scrip" where both engines FAIL it.
# ARMS, both modes, one witness file of three tests:
#   (1) error(instantiation_error), goal raises the real error   -> pass  (first, so a mutant run proves it started)
#   (2) error(instantiation_error), goal throws b                -> FAIL, the ball named
#   (3) a plain test AFTER them                                  -> pass  (the run went on)
#   (4) error(type_error(integer, foo)), atom_length(abc, foo)   -> pass  (the exact formal)
#   (5) error(type_error(integer, _)), the same goal             -> pass  (a pattern that subsumes it)
#   (6) error(type_error(atom, foo)), the same goal              -> FAIL  (a shared functor, a different formal)
# FAIL-ONCE: M1 restores the old error(_,_)-only catch and must leave arm (3) without a verdict; M2 restores the functor-only match and
# must pass arm (6).
set -u
GATE_NAME=test_gate_pl_swi_shim_grades_an_error_expectation_as_plunit_does
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
CORPUS="${S4E_CORPUS:-$ROOT/corpus}"
PLUNIT="$CORPUS/tests/prolog/plunit.pl"
SCRIP="$HERE/../../SCRIP/scrip"; RT="${RT_DIR:-$HERE/../../SCRIP/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -f "$PLUNIT" ] || refuse "no shim at $PLUNIT"
[ -x "$SCRIP" ] || refuse "no scrip binary -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
grep -q 'catch(Goal, B, pj_err_ball(Suite,Name,Exp,B))' "$PLUNIT" || refuse "the shim's whole-ball catch is not where this gate expects it -- M1 would be a no-op"
grep -q 'subsumes_term(ExpC, Act) -> pj_inc_pass' "$PLUNIT" || refuse "the shim's subsumption match is not where this gate expects it -- M2 would be a no-op"
sed 's/catch(Goal, B, pj_err_ball(Suite,Name,Exp,B))/catch(Goal, error(Act,_), pj_match_err(Suite,Name,Exp,Act))/' "$PLUNIT" > "$T/plunit_old.pl"
sed 's/( subsumes_term(ExpC, Act) -> pj_inc_pass/( functor(ExpC,F,_), functor(Act,F,_) -> pj_inc_pass/' "$PLUNIT" > "$T/plunit_m2.pl"
# ⛔ A MUTANT MUST EXIST AND DIFFER BEFORE ITS RED IS TRUSTED: a missing mutant file makes the run print nothing, and "no verdict" would
# then read as the defect reproduced (measured on this gate's own first draft, whose M1 never existed and still read 2 of 2).
for m in plunit_old plunit_m2; do [ -s "$T/$m.pl" ] || refuse "mutant $m was not written"; cmp -s "$PLUNIT" "$T/$m.pl" && refuse "mutant $m equals the live shim"; done

printf 'main :- run_tests.\n:- initialization(main).\n' > "$T/wrap.pl"
cat > "$T/w.pl" <<'EOP'
:- begin_tests(ball).
test(real, [error(instantiation_error)]) :- atom_length(_, _).
test(ball, [error(instantiation_error)]) :- throw(b).
test(after) :- true.
test(exact, [error(type_error(integer, foo))]) :- atom_length(abc, foo).
test(pattern, [error(type_error(integer, _))]) :- atom_length(abc, foo).
test(wrong, [error(type_error(atom, foo))]) :- atom_length(abc, foo).
:- end_tests(ball).
EOP
run() { local mode="$1" shim="$2"
    if [ "$mode" = m4 ]; then timeout -k 5 60 "$SCRIP" --compile "$shim" "$T/w.pl" "$T/wrap.pl" > "$T/p.s" 2>/dev/null < /dev/null \
        && gcc -no-pie "$T/p.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$T/p" 2>/dev/null && timeout -k 5 60 "$T/p" < /dev/null 2>/dev/null
    else timeout -k 5 60 "$SCRIP" --run "$shim" "$T/w.pl" "$T/wrap.pl" < /dev/null 2>/dev/null; fi; }
verdict() { grep -E "^\s+(pass|FAIL|skip):\s+ball:$1\b" <<<"$2" | head -1 | awk '{print $1}' | tr -d ':'; }
red=0; total=0; mutred=0; m2red=0; nm=0
for mode in ${MODES//,/ }; do
    nm=$((nm+1)); out="$(run "$mode" "$PLUNIT")"; old="$(run "$mode" "$T/plunit_old.pl")"; m2="$(run "$mode" "$T/plunit_m2.pl")"
    for a in "ball FAIL" "real pass" "after pass" "exact pass" "pattern pass" "wrong FAIL"; do
        set -- $a; total=$((total+1)); got="$(verdict "$1" "$out")"
        if [ "$got" = "$2" ]; then echo "  ok  $mode ball:$1 -> $got"; else echo "  RED $mode ball:$1 -> '${got}' want $2"; red=$((red+1)); fi
    done
    grep -q 'ball:ball  (received b)' <<<"$out" && echo "  ok  $mode the FAIL names the ball" || { echo "  RED $mode the FAIL does not name the ball b"; red=$((red+1)); }
    [ -z "$(verdict after "$old")" ] && [ "$(verdict real "$old")" = pass ] && mutred=$((mutred+1))
    [ "$(verdict wrong "$m2")" = pass ] && m2red=$((m2red+1))
done
echo "  FAIL-ONCE M1: with the old catch, ball:after has no verdict in $mutred of $nm mode(s) (want all)"
echo "  FAIL-ONCE M2: with the functor-only match, ball:wrong reads pass in $m2red of $nm mode(s) (want all)"
[ "$m2red" = "$nm" ] || { echo "⛔ $GATE_NAME RED: the functor-only match did not false-pass ball:wrong -- the gate cannot see the defect"; red=$((red+1)); }
[ "$mutred" = "$nm" ] || { echo "⛔ $GATE_NAME RED: the old catch did not lose the later case -- the gate cannot see the defect"; red=$((red+1)); }
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
