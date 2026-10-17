#!/usr/bin/env bash
# control_arm_population.sh -- THE POPULATION HALF OF A SHARED-NODE CONTROL ARM (coo 2026-09-17, ceo CEO-827 (3)).
#
# WHERE THIS RUNS.  A board run holds ONE reading and can diff nothing, and under CEO-775 each language runner
# produces exactly one board per landing -- so THE ONLY PLACE TWO READINGS OF ONE SUITE EXIST AT ONCE is the
# base-vs-head control arm the SHARED-NODE VERDICT SCOPE bar already requires.  That arm hands both readings here,
# and THE DIFF'S VERDICT BECOMES PART OF THE ARM'S VERDICT (CEO-827): "no worse than the clean tree" has always
# meant the pass count, and a landing can hold the pass count while three programs stop being graded.
#
#   bash ../harness/scripts/control_arm_population.sh BASE_OUT HEAD_OUT
#
# Each argument is the runner's FULL saved output for one tree -- stdout and stderr together, captured with
# SUITE_LIST_ALL=1 set, e.g.:
#   SUITE_LIST_ALL=1 bash ../harness/scripts/test_corpus_snobol4.sh > /tmp/base.out 2>&1
#
# ⛔ SUITE_LIST_ALL IS ENFORCED HERE, NOT REQUESTED.  Without it the harness prints a 40-line SAMPLE of its non-PASS
# entries, and three skips in a 1982-entry board are exactly what a sample hides -- so a reading that names no
# entries at all makes this arm REFUSE rc=2 rather than hand back a verdict it cannot support with names.
#   rc=0  the population is identical: the pass counts either side are comparable, and the arm may proceed.
#   rc=1  a SKIP count or the graded denominator MOVED -- named, with the entries where they are nameable.
#   rc=2  could not measure: a missing file, no board line, no entry lines, or two readings of different suites.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="$HERE/util_suite_population_diff.py"
refuse(){ echo "⛔ CONTROL-ARM POPULATION REFUSED (rc=2): $*"; exit 2; }
[ $# -eq 2 ] || refuse "give exactly two readings: BASE_OUT HEAD_OUT (each the runner's full output for one tree)"
[ -f "$D" ] || refuse "no instrument at $D"
BASE="$1"; HEAD="$2"
for f in "$BASE" "$HEAD"; do
  [ -f "$f" ] || refuse "$f does not exist -- nothing was read, and that is not a zero"
  grep -q 'SUITE_BOARD ' "$f" || refuse "$f carries no SUITE_BOARD line: this is not a runner's output"
done
# the entry-line requirement: at least one reading must name its non-PASS entries, or a moved skip can never be named
if ! grep -qE '^  [A-Z]+(\([^)]*\))? (m3|m4) [^ ]+:' "$BASE" && ! grep -qE '^  [A-Z]+(\([^)]*\))? (m3|m4) [^ ]+:' "$HEAD"; then
  refuse "neither reading carries the runner's per-entry lines -- re-run BOTH arms with SUITE_LIST_ALL=1 and keep stderr. \
A 40-line sample is exactly where three skips hide in a 1982-entry board (CEO-827)"
fi
echo "=== control arm: the POPULATION half (skip counts and the graded denominator), base -> head ==="
python3 "$D" "$BASE" "$HEAD"; rc=$?
echo "--- the two verbatim board lines, for the receipt (CEO-827: a receipt that paraphrases its board cannot be compared) ---"
grep -h -m1 'SUITE_BOARD ' "$BASE" | sed 's/^/  base: /'
grep -h -m1 'SUITE_BOARD ' "$HEAD" | sed 's/^/  head: /'
if [ "$rc" = 0 ]; then
  echo "CONTROL-ARM POPULATION PASS: the population is identical; the pass counts on either side are comparable."
elif [ "$rc" = 1 ]; then
  echo "⛔ CONTROL-ARM POPULATION RED: the population moved under this landing. The pass counts are NOT comparable "
  echo "   across it -- name the entries above and row them, or record the criterion change. This verdict is part of "
  echo "   the control arm's verdict (CEO-827), not an advisory beside it."
fi
exit $rc
