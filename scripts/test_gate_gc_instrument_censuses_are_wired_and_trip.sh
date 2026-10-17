#!/usr/bin/env bash
# test_gate_gc_instrument_censuses_are_wired_and_trip.sh -- THE COLLECTOR GUESSES NOTHING: THE INSTRUMENTS ARE WIRED,
# THEY TRIP, AND THE COUNTS ONLY FALL (coo 2026-09-17; row gc-instruments-the-safe-point-census-the-maps-census-and-
# scrip-gc-coverage-words-scanned-zero-are-wired-gates; CEO-812 the law, CEO-818/819 section 7 F6 step 6).
#
# WHAT THIS GATE IS FOR.  The five censuses are RED today and stay red until the design lands -- that is the point of
# them, and it is exactly why they cannot grade themselves.  A census that reports success while counting nothing is
# THE recurring failure (RULES.md THE INSTRUMENT LAWS), so this gate grades the INSTRUMENTS, not the collector:
#   (a) every census trips on a PLANTED violation and passes a clean fixture -- util_gc_census.py --selftest, 39 arms COUNTED as they run (the arm asserts >= 25; the tool itself refuses below its own floor)
#   (b) all six censuses run on THIS tree and each prints its population and a verdict; none is silent, none crashes
#   (c) THE RATCHET: every count is exactly its baseline (../harness/scripts/gc_census_baseline.tsv).  UP is a regression; DOWN
#       with the baseline unchanged is a win nobody recorded, and a loose ratchet lets the next regression back in --
#       the landing that earns the fall runs `util_gc_census.py all --write-baseline ../harness/scripts/gc_census_baseline.tsv`
#   (d) the maps census reports its TWO HALVES separately (slot-kind over the languages' rung suites; the section 6.4 table
#       from three independent producers) -- a green slot-kind half folded over an absent table would read as if the
#       design existed -- and a partial language sweep NAMES itself as partial rather than reading as coverage
#   (e) hq_snocone's DECIDABLE TEST runs, and its verdict is consistent with the conservative census: "the collector
#       finds the roots" (rc=0) is admissible only when the word walker is gone (conservative count 0).  A green
#       decidable test beside a live word walker would mean the instrument is lying, and that is a RED here.
# FAIL_ONCE=1 blanks the selftest's proof line before arm (a) asserts, to prove the arm trips.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE/../../SCRIP" || exit 2
CEN="$HERE/util_gc_census.py"; DEC="$HERE/util_gc_decidable_roots.sh"; BASE="$HERE/gc_census_baseline.tsv"
refuse(){ echo "⛔ REFUSED-TO-GRADE (rc=2): $*"; exit 2; }
[ -f "$CEN" ] || refuse "no census instrument at $CEN"
[ -f "$DEC" ] || refuse "no decidable test at $DEC"
[ -f "$BASE" ] || refuse "no ratchet baseline at $BASE"
[ -x ./scrip ] || refuse "no ./scrip binary -- run make"
bash ../harness/scripts/util_require_fresh.sh >/dev/null 2>&1 || refuse "the binary is older than src/ -- could not measure"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: the GC censuses are wired, they trip on planted violations, and their counts only fall ==="

# (a) the planted-violation proof
st="$(timeout -k 5 120s python3 "$CEN" --selftest 2>&1)"; strc=$?
[ "$strc" = 124 ] && refuse "the census selftest timed out (load $(cut -d' ' -f1 /proc/loadavg))"
[ -n "${FAIL_ONCE:-}" ] && st="$(printf '%s\n' "$st" | grep -v '^SELFTEST PASS')"
arms="$(printf '%s\n' "$st" | sed -n 's/^population: \([0-9]*\) selftest arm(s).*/\1/p')"
if printf '%s\n' "$st" | grep -q '^SELFTEST PASS' && [ "$strc" = 0 ] && [ "${arms:-0}" -ge 25 ]; then
  ck ok "(a) every census trips on a planted violation and passes its clean fixture -- $arms selftest arms, 0 FAIL"
else
  ck no "(a) the census selftest did not pass (rc=$strc, arms=${arms:-none}): $(printf '%s\n' "$st" | grep -m3 '  FAIL  ' | tr '\n' ';')"
fi

# (b)+(c)+(d) the censuses on this tree, and the ratchet
out="$(timeout -k 5 600s python3 "$CEN" all --ratchet "$BASE" 2>&1)"; crc=$?
[ "$crc" = 124 ] && refuse "the census run timed out (load $(cut -d' ' -f1 /proc/loadavg))"
verdicts="$(printf '%s\n' "$out" | grep -cE '^CENSUS [a-z-]+ (GREEN|RED|REFUSED\(2\))|^CENSUS [a-z-]+ .*(GREEN|RED)$')"
pop="$(printf '%s\n' "$out" | sed -n 's/^population: \([0-9]*\) census(es).*/\1/p' | head -1)"
if [ "${pop:-0}" = 6 ] && [ "$crc" != 124 ] && printf '%s\n' "$out" | grep -q '^population: 6 census(es)'; then
  ck ok "(b) all 6 censuses ran and printed their populations: $(printf '%s\n' "$out" | grep -m1 '^population: 6 census')"
else
  ck no "(b) the censuses did not all report (rc=$crc, population='${pop:-none}', verdict lines=$verdicts)"
fi
if printf '%s\n' "$out" | grep -q '^RATCHET GREEN'; then
  ck ok "(c) the ratchet holds: $(printf '%s\n' "$out" | grep -m1 '^population: .*ratcheted count')"
else
  ck no "(c) the ratchet is not green -- $(printf '%s\n' "$out" | grep -m2 -E '⛔ WORSE|⭐ BETTER|NOT-MEASURED|^RATCHET (RED|REFUSED)' | tr '\n' ';')"
fi
mapsline="$(printf '%s\n' "$out" | grep -m1 '^CENSUS maps slot-kind=')"
if [ -n "$mapsline" ] && printf '%s\n' "$out" | grep -q '^CENSUS maps/slot-kind swept' && printf '%s\n' "$out" | grep -qE '^CENSUS maps/table .* (GREEN|RED)$|^CENSUS maps/table REFUSED'; then
  ck ok "(d) the maps census reports its two halves SEPARATELY -- $mapsline"
else
  ck no "(d) the maps census did not report both halves (a green slot-kind half folded over an absent table would read as if the design existed): ${mapsline:-no verdict line}"
fi
if printf '%s\n' "$out" | grep -q 'A PARTIAL SWEEP IS NOT ALL-LANGUAGE COVERAGE' || printf '%s\n' "$out" | grep -q "swept ${ZLS_ALL:-7} of ${ZLS_ALL:-7}"; then
  ck ok "(d2) a partial slot-kind sweep NAMES itself as partial: $(printf '%s\n' "$out" | grep -m1 '^CENSUS maps/slot-kind swept' | sed 's/.*swept/swept/' | cut -c1-96)"
else
  ck no "(d2) the slot-kind half neither swept all seven languages nor said it was partial -- a partial sweep read as coverage is the instrument lying"
fi

# (e) the decidable test, and its consistency with the conservative census
cons="$(printf '%s\n' "$out" | sed -n 's/^CENSUS conservative total=\([0-9]*\).*/\1/p' | head -1)"
dec="$(timeout -k 5 600s bash "$DEC" 2>&1)"; drc=$?
[ "$drc" = 124 ] && refuse "the decidable test timed out (load $(cut -d' ' -f1 /proc/loadavg))"
decline="$(printf '%s\n' "$dec" | grep -m1 -E 'DECIDABLE-TEST rc=|REFUSED-TO-DECIDE')"
case "$drc:${cons:-x}" in
  2:*)   ck no "(e) the decidable test could not measure: $decline" ;;
  1:0)   ck no "(e) the decidable test says the roots are lost while the conservative census reads 0 -- the walker is gone and the roots are still not found: $decline" ;;
  1:*)   ck ok "(e) the decidable test is DECIDED and consistent with a live word walker (conservative total=$cons): a suite is green while the collector does not find the roots -- $(printf '%s\n' "$dec" | grep -cE '^  coll\..* RED') of the collected arms red" ;;
  0:0)   ck ok "(e) the decidable test reads rc=0 with the word walker gone (conservative total=0) -- a green reading now implies mapped roots" ;;
  0:*)   ck no "(e) the decidable test reads GREEN while the word walker is still in the build (conservative total=$cons) -- the roots are being found by the guess, so the instrument is lying, not passing" ;;
  *)     ck no "(e) the decidable test exited $drc, which is not a verdict: $decline" ;;
esac

# (f) the wiring
if grep -q 'test_gate_gc_instrument_censuses_are_wired_and_trip.sh' Makefile; then
  ck ok "(f) this gate is wired into the Makefile's blocking set"
else
  ck no "(f) this gate is not named in the Makefile -- an instrument nobody runs is not an instrument"
fi

echo "population: $checks arm(s) graded, $fails FAIL; census rc=$crc (the censuses being red or refused IS the design state, not this gate's verdict), decidable rc=$drc"
[ "$fails" = 0 ] && { echo "GATE PASS [gc_instrument_censuses_are_wired_and_trip]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [gc_instrument_censuses_are_wired_and_trip]: $fails of $checks arms FAIL"; exit 1
