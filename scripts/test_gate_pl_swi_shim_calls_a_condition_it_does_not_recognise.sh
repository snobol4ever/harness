#!/usr/bin/env bash
# test_gate_pl_swi_shim_calls_a_condition_it_does_not_recognise.sh -- the plunit shim (corpus/tests/prolog/plunit.pl) CALLS a test's
# condition(C) goal, as plunit does: the test runs when C succeeds and is skipped when C fails or raises (hq_prolog to the coo,
# 2026-10-14 12:4x). THE DEFECT, MEASURED: pj_cond_fails/1 knew fail, false, true and current_prolog_flag/2, and its last clause
# `pj_cond_fails(_) :- true` SKIPPED every other condition unrun -- core/test_locale's collation_key:WCSXFRM_BUFFER_OVERRUN carries
# condition(\+ current_prolog_flag(apple, true)); swipl runs it and passes, the shim printed skip in both modes, 97/98 for no SCRIP reason.
# ARMS, both modes, one witness file of four tests:
#   (1) condition(\+ fail)             runs -> pass      (the unrecognised shape that was skipped)
#   (2) condition((X = 1, X > 0))      runs -> pass      (a conjunction, also unrecognised)
#   (3) condition(\+ true)             no line           (a condition that fails skips and prints NOTHING, as swipl's plunit prints
#                                                          nothing for it -- hq_prolog 2026-10-14, corpus: a printed skip took an instance number)
#   (4) condition(no_such_pred_xyz)    no line           (a condition that raises skips the same way, as plunit treats it)
#   (5) two tests named dup, the first condition-false, the second run: exactly ONE line for cond:dup, a pass -- the pairing the oracle's
#       one line meets (tabling_clpfd:fib_error)
# FAIL-ONCE: the same witness against a copy of the shim with the old last clause restored must leave arms (1) and (2) with no line.
set -u
GATE_NAME=test_gate_pl_swi_shim_calls_a_condition_it_does_not_recognise
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
grep -q 'pj_cond_fails(C) :- \\+ catch(C, _, fail)' "$PLUNIT" || refuse "the shim's calling clause is not where this gate expects it -- the mutant would be a no-op"
sed 's/^pj_cond_fails(C) :- \\+ catch(C, _, fail)\..*$/pj_cond_fails(_) :- true./' "$PLUNIT" > "$T/plunit_old.pl"
cmp -s "$PLUNIT" "$T/plunit_old.pl" && refuse "the mutant shim equals the live one"
printf 'main :- run_tests.\n:- initialization(main).\n' > "$T/wrap.pl"
cat > "$T/w.pl" <<'EOP'
:- begin_tests(cond).
test(neg_fail, [condition(\+ fail)]) :- true.
test(conj, [condition((X = 1, X > 0))]) :- true.
test(neg_true, [condition(\+ true)]) :- true.
test(raises, [condition(no_such_pred_xyz)]) :- true.
test(dup, [condition(fail)]) :- true.
test(dup, [condition(true)]) :- true.
:- end_tests(cond).
EOP
run() { local mode="$1" shim="$2"
    if [ "$mode" = m4 ]; then timeout -k 5 60 "$SCRIP" --compile "$shim" "$T/w.pl" "$T/wrap.pl" > "$T/p.s" 2>/dev/null < /dev/null \
        && gcc -no-pie "$T/p.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$T/p" 2>/dev/null && timeout -k 5 60 "$T/p" < /dev/null 2>/dev/null
    else timeout -k 5 60 "$SCRIP" --run "$shim" "$T/w.pl" "$T/wrap.pl" < /dev/null 2>/dev/null; fi; }
verdict() { grep -E "^\s+(pass|FAIL|skip):\s+cond:$1\b" <<<"$2" | head -1 | awk '{print $1}' | tr -d ':'; }
red=0; total=0; mutred=0
for mode in ${MODES//,/ }; do
    out="$(run "$mode" "$PLUNIT")"; old="$(run "$mode" "$T/plunit_old.pl")"
    for a in "neg_fail pass" "conj pass" "neg_true none" "raises none"; do
        set -- $a; total=$((total+1)); got="$(verdict "$1" "$out")"; got="${got:-none}"
        if [ "$got" = "$2" ]; then echo "  ok  $mode cond:$1 -> $got"; else echo "  RED $mode cond:$1 -> '${got}' want $2"; red=$((red+1)); fi
    done
    total=$((total+1)); nd=$(grep -cE "^\s+(pass|FAIL|skip):\s+cond:dup\b" <<<"$out")
    if [ "$nd" = 1 ] && [ "$(verdict dup "$out")" = pass ]; then echo "  ok  $mode cond:dup -> one line, pass"; else echo "  RED $mode cond:dup -> $nd line(s), first '$(verdict dup "$out")' want 1 pass"; red=$((red+1)); fi
    [ "$(verdict dup "$old")" = pass ] && for t in neg_fail conj; do [ -z "$(verdict "$t" "$old")" ] && mutred=$((mutred+1)); done
done
want_mut=$(( 2 * $(tr ',' '\n' <<<"$MODES" | grep -c .) ))
echo "  FAIL-ONCE: the old clause leaves $mutred of $want_mut runnable-condition cases with no line, its run test printed (want all)"
[ "$mutred" = "$want_mut" ] || { echo "⛔ $GATE_NAME RED: the mutant with the old clause did not skip arms (1) and (2) -- the gate cannot see the defect"; red=$((red+1)); }
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
