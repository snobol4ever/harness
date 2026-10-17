#!/usr/bin/env bash
# test_gate_suite_partitions_are_current.sh -- EVERY SUITE TABLE CARRIES A STORED PARTITION THAT A REBUILD REPRODUCES (Lon 2026-10-11 13:0x CDT:
# "subsets need to be identified independent of a query against the attribute file for the long running test suites. So to partition them as major
# cores, and shells around that core with each major feature broken out."; ceo CEO-1676; RULES.md section ONE TESTING OFFICER clause (9);
# ARCH-SUITE-PARTITIONS.md). For every ALL.csv under corpus/tests/<lang>/ and corpus/packages/<lang>/<pkg>/, util_suite_partition.py check must read
# CURRENT: a table edited without `util_suite_partition.py build <ALL.csv>` in the same landing is a RED, named; a missing PARTITION.tsv is a RED too.
# rc 0 every partition current; 1 a stale or missing one, named; 2 no table found (a census that cannot look reports nothing, never zero).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
C="${S4E_CORPUS:-${S4E_HOME:-$(cd "$ROOT/.." && pwd)}/corpus}"
tables=$(ls "$C"/tests/*/ALL.csv "$C"/packages/*/*/ALL.csv 2>/dev/null)
[ -n "$tables" ] || { echo "REFUSE(2) [suite_partitions_are_current]: no ALL.csv under $C/tests or $C/packages"; exit 2; }
n=0; bad=0; names=""
for t in $tables; do
  n=$((n + 1))
  out=$(python3 "$HERE/util_suite_partition.py" check "$t" 2>&1); rc=$?
  if [ "$rc" != 0 ]; then bad=$((bad + 1)); names="$names ${t#$C/}"; echo "  RED  $out" | cut -c1-200; fi
done
echo "SUITE_PARTITIONS tables=$n current=$((n - bad)) stale_or_missing=$bad"
[ "$bad" = 0 ] && { echo "GATE PASS(0) [suite_partitions_are_current]: every suite table's PARTITION.tsv is what a rebuild gives"; exit 0; }
echo "GATE FAIL(1) [suite_partitions_are_current]: rebuild with util_suite_partition.py build <ALL.csv> for:$names"; exit 1
