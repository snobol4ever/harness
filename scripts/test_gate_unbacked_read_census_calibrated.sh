#!/bin/bash
# test_gate_unbacked_read_census_calibrated.sh -- THE UNBACKED-READ CENSUS READS BOTH WAYS (ceo CEO-1948; row zeta-the-unbacked-read-census-...).
# util_zop_unbacked_census.py (the cfo's instrument, extended with --ref/--master/--workers/--board under this row) compiles every master entry on a scratch
# build of a SCRIP ref with x86_zop's unbacked-key abort swapped for a count line, and prints UNBACKED_BOARD lang=<l> programs=<n> screaming=<s> reads=<r>.
# This gate trusts it only when it tells a clean language from a screaming one: ARM 1 snobol4 at origin/main reads programs>0 and reads=0; ARM 2 prolog at
# the whack-all tree (every non-root graph on the home frame; the annotated SCRIP tag whack-all-2026-10-24 at c37f6c77c, which outlives the wip branch,
# CEO-1951) reads reads>0. rc 0 both arms hold; rc 1 an arm fails or the instrument is missing; rc 2 cannot measure.
HERE="$(cd "$(dirname "$0")" && pwd)"; C="$HERE/util_zop_unbacked_census.py"
[ -f "$C" ] || { echo "RED: $C does not exist yet (the row builds it)"; exit 1; }
a1="$(python3 "$C" --ref origin/main --master snobol4 --board 2>&1 | grep '^UNBACKED_BOARD lang=snobol4 ' | tail -1)"
a2="$(python3 "$C" --ref whack-all-2026-10-24 --master prolog --board 2>&1 | grep '^UNBACKED_BOARD lang=prolog ' | tail -1)"
echo "ARM1 ${a1:-no board line}"; echo "ARM2 ${a2:-no board line}"
[ -n "$a1" ] && [ -n "$a2" ] || { echo "REFUSE(2): the census printed no board line for an arm"; exit 2; }
n1="$(echo "$a1" | sed -n 's/.* programs=\([0-9]*\).*/\1/p')"; u1="$(echo "$a1" | sed -n 's/.* reads=\([0-9]*\).*/\1/p')"; u2="$(echo "$a2" | sed -n 's/.* reads=\([0-9]*\).*/\1/p')"
[ "${n1:-0}" -gt 0 ] && [ "${u1:-1}" -eq 0 ] || { echo "RED ARM1: snobol4 at origin/main must read programs>0 reads=0"; exit 1; }
[ "${u2:-0}" -gt 0 ] || { echo "RED ARM2: prolog on the whack-all tag must read reads>0 -- the census cannot see a scream"; exit 1; }
echo "GATE OK -- the census reads 0 on a clean language and ${u2} unbacked reads on the screaming one"
