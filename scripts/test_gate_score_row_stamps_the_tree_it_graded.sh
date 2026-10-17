#!/usr/bin/env bash
export S4E_DB_CHECK_OVERRIDE="gate fixture: this gate plants no progress rows (util_score_row.py db_crosscheck, hq_raku 2026-09-16)"
# test_gate_score_row_stamps_the_tree_it_graded.sh -- GATE (hq_T 2026-09-08).
# ⛔⭐ THE HAZARD, MEASURED THREE TIMES IN ONE SITTING AND TWICE WHILE DOING THE DISCIPLINED THING. A board takes
# ten to forty minutes; its SCORE.md write happens at the END. A seat who commits and pushes mid-run moves HEAD
# under a measurement that already happened, and the row then names a tree carrying commits it never ran.
# ⭐ AND THE GUARD PUSHES YOU INTO IT. CEO-174 skips the write on a dirty tree, so the way to make your row land is
# to commit before the board finishes -- which is exactly the act that moves HEAD. The safeguard and the hazard
# are the same gesture, which is why care does not protect against this one and a mechanism has to.
# ⛔ IT ASSERTS BEHAVIOUR, NOT WIRING: unset, the stamp must be byte-identical to what it always was, because
# every runner that has not been taught the variable still has to publish exactly as before.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
U="$HERE/util_score_row.py"
[ -f "$U" ] || { echo "⛔ GATE REFUSES (rc=2): util_score_row.py is not at $U -- the writer moved; re-pin rather than reinterpret."; exit 2; }
FAIL=0; N=0
arm() { N=$((N+1)); if [ "$1" = 0 ]; then echo "  ✅ $2"; else echo "  ⛔ $2"; FAIL=$((FAIL+1)); fi; }
stamp() { python3 - "$U" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("u", sys.argv[1]); u = importlib.util.module_from_spec(spec)
try: spec.loader.exec_module(u)
except Exception as e: print("IMPORT-FAILED %s: %s" % (type(e).__name__, e)); raise SystemExit(0)
if not hasattr(u, "tree_stamp"): print("NO-TREE-STAMP"); raise SystemExit(0)
print(u.tree_stamp())
PY
}
BASE="$(S4E_TREE_AT_START= stamp)"
case "$BASE" in IMPORT-FAILED*|NO-TREE-STAMP) echo "⛔ GATE REFUSES (rc=2): $BASE -- cannot grade a stamp this build does not produce."; exit 2;; esac
[ -n "$BASE" ]; arm $? "tree_stamp() produces a stamp with the variable unset"
MOVED="$(S4E_TREE_AT_START='SCRIP=d15ea5e,corpus=b0a1e5e' stamp)"
# ⛔⭐ PURE-BASH MATCHING, NO PIPELINE (hq_T 2026-09-09, FINDING .github 9142ec58). These four arms decided their verdict
# through `printf | grep -q`, and a pipeline whose reader exits on match can kill the writer with EPIPE -- under
# `set -o pipefail` that 141 becomes the arm's answer, so the arm REDS on a correct tree. MEASURED on the same shape
# elsewhere: 11 false negatives in 2712 calls at box load 21, every one exit 141. ⛔ An arm that can red for a reason
# unrelated to its subject is worse than no arm, because it sends a reader to look at provenance code that is fine --
# and this gate's subject IS provenance, so a false red here impeaches the tree stamps every board cites.
# `case`/`[[ ]]` matching forks nothing and cannot be interrupted.
[[ "$MOVED" == *d15ea5e* && "$MOVED" == *b0a1e5e* ]]; arm $? "a declared start tree is what gets STAMPED, for every repo the row reads"
shopt -s nocasematch; [[ "$MOVED" == *"HEAD moved"* ]]; _hm=$?; shopt -u nocasematch; arm $_hm "and the stamp SAYS the tree moved -- the reader is told the number predates this HEAD, not just given a different hash"
SAME="$(S4E_TREE_AT_START= stamp)"
[ "$SAME" = "$BASE" ]; arm $? "unset is byte-identical to the previous behaviour (no runner is broken by not knowing the variable)"
# ⛔ AND THE START TREE MUST NOT BE ABLE TO ERASE THE DIRTY MARK: a dirty run is unpublishable whatever tree it names.
if [[ "$BASE" == *-DIRTY* ]]; then
    [[ "$MOVED" == *-DIRTY* ]]; arm $? "a DIRTY worktree stays marked DIRTY when a start tree is declared"
fi
echo "graded $N arm(s)"
[ "$N" = 0 ] && { echo "⛔ GATE REFUSES (rc=2): graded zero arms."; exit 2; }
[ "$FAIL" != 0 ] && { echo "⛔ GATE FAIL: $FAIL of $N arm(s) red"; exit 1; }
echo "✅ GATE OK: $N/$N -- a row stamps the tree its run GRADED, and says so when HEAD moved underneath it."
