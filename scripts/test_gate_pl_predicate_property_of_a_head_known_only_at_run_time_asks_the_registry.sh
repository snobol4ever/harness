#!/usr/bin/env bash
# test_gate_pl_predicate_property_of_a_head_known_only_at_run_time_asks_the_registry.sh
#
# THE ROW: prolog-a-run-time-dynamic-1-records-the-predicate-and-predicate-property-of-a-head-the-compiler-never-saw-asks-the-
# registry (cfo; found by the ceo, CEO-1523). predicate_property/2 written with a constant head is answered by the lowerer
# from what the compiler knows; a head it knows nothing about (a predicate a run-time consult, a run-time dynamic/1 or an
# assertz brings in) compiled to plain failure. It now goes to the run-time enumerator ($pl_pp_count/$pl_pp_nth) the
# variable-head case uses, so the registry answers.
#
# One program x two modes: a file named at run time is consulted (its dynamic directive in canonical form), dynamic/1 is
# called at run time, a predicate is asserted at run time, and each is asked about with a constant head; the answers are
# swipl's. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
printf ':-(dynamic(/(d,1))).\nd(1).\n' > "$D/gen.txt"
cat > "$D/w.pl" <<'PL'
:- initialization(main).
main :- F = 'gen.txt', consult(F), dynamic(e/1), assertz(f(1)),
  ( predicate_property(d(_), dynamic) -> write(d_dynamic) ; write(d_not) ), nl,
  ( predicate_property(e(_), dynamic) -> write(e_dynamic) ; write(e_not) ), nl,
  ( predicate_property(f(_), dynamic) -> write(f_dynamic) ; write(f_not) ), nl,
  ( predicate_property(d(_), defined) -> write(d_defined) ; write(d_undefined) ), nl,
  ( predicate_property(g(_), dynamic) -> write(g_dynamic) ; write(g_not) ), nl.
PL
printf 'd_dynamic\ne_dynamic\nf_dynamic\nd_defined\ng_not\n' > "$D/want"
( cd "$D" && timeout -k 5 30 "$B/scrip" w.pl < /dev/null > m3 2>/dev/null )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o w.bin 2>/dev/null ) || refuse "w.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 30 ./w.bin < /dev/null > m4 2>/dev/null )
red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  ok   $m: the registry answers for heads known only at run time"
    else echo "  FAIL $m: got [$(tr '\n' '|' < "$D/$m")] want [$(tr '\n' '|' < "$D/want")]"; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): predicate_property/2 of a head known only at run time asks the registry, both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
