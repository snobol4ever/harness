#!/bin/bash
# test_icon_ir_rung_03.sh -- RETIRED INSTRUMENT, REFUSES rc=2. Read this header before reviving it.
#
# ⛔⭐ THIS SCRIPT GRADED NOTHING AND REPORTED rc=1, WHICH READS AS "the tests failed" (hq_T 2026-09-11,
# routed by hq_V). It was written 2026-09-03 against four loose witnesses, rung03_suspend_{gen,gen_compose,
# gen_filter,return}.icn. Those four were absorbed into the Icon rungs by hq_V's 2026-09-09 landing and the
# loose .icn/.ref pairs deleted at corpus `249f653a6`, so the glob below matched nothing, `set -e` carried an
# unmatched glob into `cat "$expected"`, and the script died rc=1 having graded ZERO witnesses.
# ⭐ rc=1 IS THE WRONG FAILURE AND THAT IS THE POINT: RULES.md's "a test that cannot measure REFUSES rc=2"
# exists because a FAIL and a CANNOT-MEASURE are different facts. This script emitted the first while meaning
# the second -- a FALSE RED, which is the mirror of the false green `make test` used to print, and costs a
# reader the same way: it invites a hunt for a defect in Icon that is really a defect in the instrument.
#
# ⛔ IT ALSO HAD A PATH BUG INDEPENDENT OF ITS MISSING INPUTS, and a reviver would inherit it silently: it
# computed `$S4E` per the D-17 PORTABLE-HOME pattern and then NEVER USED IT, pathing instead through a
# hand-rolled `$SCRIPT_DIR/../../..` -- one `..` too many, resolving to /home/corpus/icon on every seat root
# rather than $S4E/corpus/icon. So even with its witnesses restored beside it, it would have graded nothing.
# ⭐ A script that derives the right answer into a variable and then walks past it is not a near-miss; the
# correct-looking derivation is what stops anyone reading the line that actually does the work.
#
# ⛔ THE CONTENT IS NOT LOST -- VERIFIED, NOT ASSUMED (hq_T 2026-09-11). The four witnesses live in the Icon
# rungs as entries 855/856/829/707, named procedure_every_suspend_8/9/10/11, origins recorded in ALL.csv as
# rung03_suspend_{gen,gen_compose,gen_filter,return}, each graded "m3,m4" -- BOTH MODES, which this script
# never did (it graded one binary, one mode). Their rungs refs were diffed against the four orphaned
# .expected files that survived the deletion and are BYTE-IDENTICAL; the orphans are deleted at corpus
# `HEAD` in the same push as this refusal. So the absorbed grading is a STRICT SUPERSET of what this ran.
#
# ⭐ TO REVIVE IT ANYWAY, materialize the inputs -- never expect loose copies, they are gone for good:
#     RUNGS_EXT=.icn RUNGS_DIR="$S4E/corpus/tests/icon" . ../harness/scripts/lib_rungs_extract.sh
#     rungs_extract_name procedure_every_suspend_8 /tmp/w.icn /tmp/w.ref     # and 9, 10, 11
#   and path via "$S4E", not a relative walk. But read board_icon_rungs.sh first: it grades the whole
#   rungs and prints its own denominator, so a family that stops being graded is already caught at the SET
#   level. Reviving this would duplicate that aggregate with a weaker, single-mode instrument.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root
CORPUS="${CORPUS_REPO:-$S4E/corpus}/icon"
n=0
for icn in "$CORPUS"/rung03_suspend_*.icn; do [ -e "$icn" ] && n=$((n+1)); done
echo "REFUSE (rc=2): graded ZERO witnesses -- the four rung03 suspend sources this script names were absorbed into the Icon rungs (procedure_every_suspend_8/9/10/11, both modes, ALL.csv origins rung03_suspend_*) and their loose copies deleted at corpus 249f653a6. Coverage is a strict superset of what this graded and lives in board_icon_rungs.sh. This script is redundant, not a hole -- and it previously reported rc=1, a FALSE RED for a condition that is a refusal. Cannot measure, not a pass. (witnesses found beside \$CORPUS=$CORPUS: $n)"
exit 2
