#!/usr/bin/env bash
# test_gate_fanout_ceiling.sh -- THE FAN-OUT CEILING IS HELD BY ITS INSTRUMENT (ceo CEO-1333, 2026-09-27 17:2x CDT; the cfo's row
# instruments-lib-fanout-a-seat-reads-the-load-before-fanning-out-...). MEASURED CAUSE: load 52.6 on 16 cores at 17:05 with three seats
# fanning out at once (14 + 13 children and a callgrind) and every other seat's proofs five times slower. THE RULE: a seat caps its
# concurrent children at max(2, min(4, cores - demand)) and runs a census serially under nice 19. WHAT THIS GATE HOLDS: (1) the helper
# exists and answers 2 at a planted load of 52 and min(4, cores - 1) at a planted load of 1, and 3 where cores - demand is 3 (FANOUT_TEST_LOAD plants the demand, CEO-1394); (2) the
# python mirror agrees with the shell helper at every planted load; (3) fanout_nice is the nice-19 prefix; (4) the live reading is a
# number in 2..4; (5) FAIL-ONCE: a planted helper without the min(4, ...) clamp reads cores - 1 at load 1 and this gate's own arm reds
# on it; (6) the fanning runners it was landed for still source the helper (a runner that stops reading the load is the defect this
# gate exists to catch). rc 2 when the helper is missing: a missing instrument is not a green.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE/../../SCRIP" || { echo "⛔ REFUSE(2): cannot cd to SCRIP root" >&2; exit 2; }
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ REFUSE(2): no lib_gate.sh" >&2; exit 2; }
GATE_NAME=fanout_ceiling; gate_parse_args "$@" 2>/dev/null || true
LIB="$HERE/lib_fanout.sh"; PY="$HERE/lib_fanout.py"
[ -f "$LIB" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: $LIB is missing -- the ceiling has no instrument"; exit 2; }
[ -f "$PY" ]  || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: $PY is missing -- the python runners have no mirror"; exit 2; }
. "$LIB"
command -v fanout_width >/dev/null || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: lib_fanout.sh sourced but fanout_width is not defined"; exit 2; }
red=0; n=0; cores=$(fanout_cores)
arm() { n=$((n+1)); if [ "$2" = "$3" ]; then echo "  ok   $n $1: $2"; else echo "  FAIL $n $1: got '$2' want '$3'"; red=$((red+1)); fi; }
want1=$(( cores - 1 )); [ "$want1" -gt 4 ] && want1=4; [ "$want1" -lt 2 ] && want1=2
arm "width at planted load 52" "$(FANOUT_TEST_LOAD=52 fanout_width)" 2
arm "width at planted load 1 (min(4, cores - 1) on $cores cores)" "$(FANOUT_TEST_LOAD=1 fanout_width)" "$want1"
arm "width at planted load cores - 3 is 3" "$(FANOUT_TEST_LOAD=$(( cores - 3 )) fanout_width)" 3
arm "width at planted load cores - 1.5 floors to 2 (int(1.5) = 1, floored to the minimum)" "$(FANOUT_TEST_LOAD=$(( cores - 2 )).5 fanout_width)" 2
for L in 1 $(( cores - 3 )) 13.7 52 200; do arm "python mirror agrees at planted load $L" "$(FANOUT_TEST_LOAD=$L python3 "$PY")" "$(FANOUT_TEST_LOAD=$L fanout_width)"; done
arm "fanout_nice is the nice-19 prefix" "$(fanout_nice)" "nice -n 19"
arm "the standalone form answers the same as the sourced one" "$(FANOUT_TEST_LOAD=52 bash "$LIB" width)" 2
live=$(fanout_width); n=$((n+1)); if [ "$live" -ge 2 ] && [ "$live" -le 4 ] 2>/dev/null; then echo "  ok   $n live width $live is within 2..4 (demand $(fanout_demand) from $(fanout_source), $cores cores)"; else echo "  FAIL $n live width '$live' is outside 2..4"; red=$((red+1)); fi
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
sed 's/if (w > 4) w = 4; //' "$LIB" > "$T/lib_fanout_unclamped.sh"
pl=$(FANOUT_TEST_LOAD=1 bash "$T/lib_fanout_unclamped.sh" width); n=$((n+1))
if [ "$cores" -gt 5 ]; then if [ "$pl" != "$want1" ] && [ "$pl" = "$(( cores - 1 ))" ]; then echo "  ok   $n FAIL-ONCE: the planted helper without the min(4, ...) clamp reads $pl at load 1 where the rule says $want1 -- arm 2 would red on it"; else echo "  FAIL $n FAIL-ONCE did not trip: planted helper read '$pl'"; red=$((red+1)); fi; else echo "  ok   $n FAIL-ONCE not decidable on $cores cores (the clamp and the floor coincide); skipped"; fi
for r in ../harness/scripts/run_blocking_set.sh ../harness/scripts/audit_template_watch.sh ../harness/scripts/util_dyn_caps_witness.sh ../harness/scripts/test_gate_dyn_caps_ratchet.sh; do n=$((n+1)); if grep -q 'lib_fanout.sh' "$r" 2>/dev/null; then echo "  ok   $n $r sources lib_fanout.sh"; else echo "  FAIL $n $r no longer reads the ceiling (lib_fanout.sh not sourced)"; red=$((red+1)); fi; done
n=$((n+1)); if grep -q 'lib_fanout' ../harness/scripts/util_parser_sc_census.py 2>/dev/null; then echo "  ok   $n ../harness/scripts/util_parser_sc_census.py takes its --jobs default from lib_fanout"; else echo "  FAIL $n ../harness/scripts/util_parser_sc_census.py no longer takes its --jobs default from lib_fanout"; red=$((red+1)); fi
GATE_EXAMINED=$n
if [ "$red" -eq 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: the fan-out ceiling max(2, min(4, cores - demand)) holds in the shell helper and its python mirror, the census prefix is nice 19, the fail-once trips, and the five fanning runners read it ($n arms)"; gate_stamp; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $red of $n arms red"; gate_stamp; exit 1
