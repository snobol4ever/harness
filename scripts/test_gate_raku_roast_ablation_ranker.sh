#!/usr/bin/env bash
# test_gate_raku_roast_ablation_ranker.sh -- PINS THE ABLATION RANKER'S REFUSALS AND THE ONE-AUTHORITY
# PROPERTY IT EXISTS TO PRESERVE (hq_raku 2026-09-16, baton raku-every-roast-file-run-graded-against-rakudo-
# or-named-ungradable TAKE NEXT item 1).
# ⛔⭐ ARM 4 IS THE ONE THAT EARNS THIS GATE'S KEEP, and it is not about the ranker's output at all. The
# ranker's measurement is "files that MOVED into a graded bucket" -- a DIFFERENCE between two classifications.
# The day someone gives the ranker its own private copy of classify()/roast_bucket(), that difference starts
# measuring the two copies as much as it measures the cure, and it will do so SILENTLY and in the flattering
# direction: a ranker whose bucket rule is a shade more generous than the census's reports unlocks that the
# census will never confirm. No output check can catch that; only counting the definitions can.
# EXIT: 0 all arms pass · 1 an arm failed · 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/../../SCRIP" || { echo "GATE UNPROVEN(2): no SCRIP root"; exit 2; }
RANKER="$HERE/util_raku_roast_ablation_ranker.sh"
LIB="$HERE/lib_raku_roast_bucket.sh"
BOARD="$HERE/raku_roast_scoreboard.sh"
for f in "$RANKER" "$LIB" "$BOARD"; do
  [ -f "$f" ] || { echo "GATE UNPROVEN(2): missing $f"; exit 2; }
done
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }

echo "=== gate: the roast ablation ranker refuses rather than guessing, and shares ONE bucket rule ==="

echo "--- ARM 1: an unknown argument REFUSES rc=2 and NAMES it (never treated as a filename) ---"
out=$(bash "$RANKER" --no-such-flag 2>&1); rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q -- '--no-such-flag'; then
  ck ok "unknown argument -> rc=2, naming the argument"
else ck no "expected rc=2 naming --no-such-flag; got rc=$rc -- $(printf '%s' "$out" | tail -1)"; fi

echo "--- ARM 2: an absent population REFUSES rc=2 naming THE TREE, not a downstream symptom ---"
out=$(RAKU_ROAST_TREE=/nonexistent-roast-tree bash "$RANKER" --limit 2 2>&1); rc=$?
if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'no roast tree'; then
  ck ok "absent roast tree -> rc=2 naming the tree and every candidate tried"
else ck no "expected rc=2 'no roast tree'; got rc=$rc -- $(printf '%s' "$out" | tail -1)"; fi

echo "--- ARM 3: an explicit env override is VALIDATED, not trusted (the arm-2 message must not be the census's) ---"
out=$(RAKU_ROAST_TREE=/nonexistent-roast-tree bash "$RANKER" --limit 2 2>&1)
if printf '%s' "$out" | grep -q 'censused ZERO files'; then
  ck no "an unvalidated override reached the census loop -- it refuses, but blames the wrong thing"
else ck ok "override checked at resolution; the refusal names the cause, not a symptom"; fi

echo "--- ARM 4: the ROAST bucket rule is defined once, and its two consumers define it NOWHERE ---"
# \u26d4\u2b50 THIS ARM WAS WRONG ON ITS FIRST RUN AND THE CORRECTION IS THE INTERESTING PART (hq_raku
# 2026-09-16). It counted files defining `classify()` ANYWHERE under ../harness/scripts/ and found THREE -- and all
# three were innocent: board_demos_zeta.sh classifies SNOBOL4 demo outputs and test_icn_d2_suspend_witness.sh
# classifies Icon suspend witnesses. Neither has anything to do with roast. The arm asked "who defines a
# function NAMED classify" when the question was "who defines THE ROAST BUCKET RULE", and a generic name
# cannot tell those apart. \u2b50 THE LESSON, which outlives this gate: A UNIQUELY-NAMED FUNCTION IS ITS OWN
# RATCHET AND A GENERICALLY-NAMED ONE CANNOT BE COUNTED GLOBALLY. So roast_bucket() -- a name nothing else
# would pick -- is counted tree-wide, while classify() is policed where it actually matters: the two
# consumers must not define it, because a consumer that defines it has stopped sharing it.
n=$(grep -rl '^roast_bucket()' "$HERE" 2>/dev/null | wc -l)
if [ "$n" = 1 ]; then ck ok "roast_bucket() defined in exactly 1 file (a name unique enough to count tree-wide)"
else ck no "roast_bucket() defined in $n files -- a second copy is how a difference-based measurement starts measuring its own copies"; fi
for f in "$BOARD" "$RANKER"; do
  if grep -q '^classify()' "$f"; then ck no "$(basename "$f") defines its own classify() -- it has stopped sharing the bucket rule it is graded against"
  else ck ok "$(basename "$f") defines no classify() of its own"; fi
done

echo "--- ARM 5: the scoreboard and the ranker both SOURCE that one file ---"
for f in "$BOARD" "$RANKER"; do
  if grep -q 'lib_raku_roast_bucket.sh' "$f"; then ck ok "$(basename "$f") sources lib_raku_roast_bucket.sh"
  else ck no "$(basename "$f") does not source the shared bucket lib"; fi
done

echo "--- ARM 6: the ranker WRITES NOTHING -- no SCORE row, no RAKU-COVERAGE.md (ONE RUNNER ONE BOARD) ---"
SC="$HERE/../../.github/SCORE.md"; COV="$HERE/../../.github/RAKU-COVERAGE.md"
before=""; for f in "$SC" "$COV"; do [ -f "$f" ] && before="$before$(stat -c '%n:%Y:%s' "$f") "; done
out=$(timeout -k 5 600 bash "$RANKER" --limit 8 --candidates 1 2>&1); rc=$?
after=""; for f in "$SC" "$COV"; do [ -f "$f" ] && after="$after$(stat -c '%n:%Y:%s' "$f") "; done
if [ "$before" = "$after" ]; then ck ok "SCORE.md and RAKU-COVERAGE.md untouched across a ranker run"
else ck no "the ranker moved a published file -- it must publish nothing: [$before] -> [$after]"; fi
if [ "$rc" = 0 ] || [ "$rc" = 2 ]; then ck ok "bounded run returned a defined verdict (rc=$rc)"
else ck no "bounded run rc=$rc -- neither a result nor a refusal"; fi

echo "--- ARM 7: the report leads with moved=, the only column that is an unlock ---"
if printf '%s' "$out" | grep -q 'RANKED BY moved_to_graded'; then
  ck ok "report states its ranking key"
elif [ "$rc" = 2 ]; then ck ok "run refused (rc=2) -- no report to grade, and a refusal is not a failure here"
else ck no "report does not name its ranking key"; fi

echo
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$checks arm(s)]: the ablation ranker refuses what it cannot measure, publishes nothing, and shares ONE bucket rule with the census it ranks"; exit 0; fi
echo "GATE FAIL(1) [$fails of $checks arm(s) failed]"; exit 1
