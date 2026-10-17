#!/usr/bin/env bash
# test_gate_pl_swi_shim_runs_a_forall_test_per_instance.sh -- the plunit shim (corpus/tests/prolog/plunit.pl) runs a test
# carrying forall(Gen) once per solution of Gen, printing one verdict line per instance, as plunit does (cto, 2026-09-12,
# row prolog-swi-shim-runs-a-forall-test-once-per-generator-instance, ceo re CTO-33). RED BEFORE: 4/94 agree on
# library/test_utf8.pl, every instance after the first reading 'no verdict from scrip'.
# ARMS, both modes: (1) a witness with a two-solution forall and a zero-solution forall prints exactly the instance lines
# plunit would; (2) library/test_utf8.pl through the shim reads hit >= 90 of 94 in util_swi_match.py.
set -u
GATE_NAME=test_gate_pl_swi_shim_runs_a_forall_test_per_instance
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
CORPUS="${S4E_CORPUS:-$ROOT/corpus}"
SWIT="$CORPUS/packages/prolog/swi_tests"; PLUNIT="$CORPUS/tests/prolog/plunit.pl"
SCRIP="$HERE/../../SCRIP/scrip"; RT="${RT_DIR:-$HERE/../../SCRIP/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -f "$PLUNIT" ] || refuse "no shim at $PLUNIT"; [ -f "$SWIT/library/test_utf8.pl" ] || refuse "no vendored test_utf8.pl"
[ -x "$SCRIP" ] || refuse "no scrip binary -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'main :- run_tests.\n:- initialization(main).\n' > "$T/wrap.pl"
red=0; total=0
run() { local mode="$1" f="$2"
    if [ "$mode" = m4 ]; then timeout -k 5 60 "$SCRIP" --compile "$PLUNIT" "$f" "$T/wrap.pl" > "$T/p.s" 2>/dev/null && gcc -no-pie "$T/p.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$T/p" 2>/dev/null && timeout -k 5 60 "$T/p" </dev/null 2>/dev/null
    else timeout -k 5 60 "$SCRIP" --run "$PLUNIT" "$f" "$T/wrap.pl" </dev/null 2>/dev/null; fi; }
cat > "$T/w.pl" <<'EOP'
:- begin_tests(fa).
gen(1). gen(2).
test(two, [forall(gen(X))]) :- X > 0.
test(none, [forall(fail)]) :- true.
test(after) :- true.
:- end_tests(fa).
EOP
want="$(printf '%s\n' '  pass: fa:two' '  pass: fa:two' '  pass: fa:after')"
for mode in ${MODES//,/ }; do
    total=$((total+1))
    got="$(run "$mode" "$T/w.pl" | grep -E '^\s+(pass|FAIL|skip):' | grep -v 'fa:none')"
    nonecount="$(run "$mode" "$T/w.pl" | grep -cE '^\s+(pass|FAIL):\s+fa:none')"
    if [ "$got" = "$want" ] && [ "$nonecount" = "0" ]; then echo "  ok  witness $mode: two instances, zero instances, then the next test"
    else echo "  RED witness $mode: got [$got] none-lines=$nonecount want [$want] none-lines=0"; red=$((red+1)); fi
    total=$((total+1))
    run "$mode" "$SWIT/library/test_utf8.pl" > "$T/act" ; line="$(python3 "$HERE/util_swi_match.py" "$SWIT/library/test_utf8.pl" "$SWIT/library/test_utf8.ref" "$T/act" | tail -1)"
    h="$(printf '%s' "$line" | sed -n 's/.* hit=\([0-9]*\).*/\1/p')"
    if [ "${h:-0}" -ge 90 ]; then echo "  ok  test_utf8 $mode: $line (floor hit>=90)"; else echo "  RED test_utf8 $mode: $line (floor hit>=90)"; red=$((red+1)); fi
done
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
