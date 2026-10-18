#!/usr/bin/env bash
# test_gate_score_md_parses_and_github_is_marker_free.sh — the second half of the conflict-marker guard
# (row `make-test-refuses-when-score-md-is-unparseable-or-a-tracked-github-file-carries-a-conflict-marker`,
# ceo CEO-370 rank 1, minted from hq_R's blocker).
#
# ⛔⭐⭐ WHY A SECOND GUARD, WHEN THE PRE-COMMIT HOOK ALREADY REFUSES MARKERS. The hook grades the commit in
# front of it, in the root where it is installed, and hooks DO NOT PROPAGATE THROUGH CLONE. It cannot see
# what already reached origin, it cannot see a --no-verify, and it cannot see a seat whose hook was never
# installed. This arm grades the TREE every seat actually pulled. The two are authoring-time and
# landing-time halves of one property; neither replaces the other.
#
# ⛔ THE INCIDENT, measured 2026-09-06: a SCORE.md landed carrying conflict markers. util_score_row.py could
# not find its table, so every runner's row-write failed -- and THE LEADERBOARD WRITER WAS DEAD FOR AN HOUR
# WHILE EVERY BOARD STILL READ GREEN. That is not a bug in either component. `gate_score_row` is non-fatal
# BY DESIGN so that a bookkeeping failure never reds somebody's board, which is right; and a corrupt shared
# file is invisible to a board, which is also expected. THE HOLE IS THE COMPOSITION: the writer may fail
# quietly AND the file may be corrupt, so nothing anywhere says so. A failed WRITE must not red a board; a
# corrupt LEADERBOARD must. This gate is that distinction, made mechanical.
#
# THE TWO VERDICTS ARE DIFFERENT ON PURPOSE (ceo's spec):
#   rc=2  the table cannot be found or parsed -- this gate CANNOT MEASURE, so it REFUSES rather than
#         inventing a verdict. An unparseable board is not a failing board; it is an unreadable one.
#   rc=1  a tracked .github file carries a column-zero conflict marker -- that IS a defect, and a real one.
#
# ⛔ IT SOURCES util_score_row.py's OWN find_table RATHER THAN REIMPLEMENTING IT. A second definition of
# "is this table readable" would drift from the one every runner actually calls, and the drift would be
# silent in exactly the direction that lets a corrupt board through. Shape is the identity, never position:
# SCORE.md carries more than one '| Language |' header and binding to the first killed this helper
# fleet-wide once already.
#
# Usage: bash ../harness/scripts/test_gate_score_md_parses_and_github_is_marker_free.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
GH="$ROOT/../.github"
HELPER="$HERE/util_score_row.py"
gate_require "$HELPER" "the one leaderboard helper util_score_row.py"
gate_require "$GH/SCORE.md" "the ONE LEADERBOARD .github/SCORE.md"
violations=0; examined=0
ck() { examined=$((examined + 1)); if [ "$1" = ok ]; then printf '  ok   %s\n' "$2"; else printf '  FAIL %s\n' "$2"; violations=$((violations + 1)); fi; }

echo "--- ARM 1 — SCORE.md's standardized display parses, through the runners' OWN reader ---"
examined=$((examined + 1))
parse_out="$(python3 - "$HELPER" "$GH/SCORE.md" <<'PY' 2>&1
import importlib.util, io, sys
helper, score = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("usr", helper)
m = importlib.util.module_from_spec(spec)
sys.argv = ["usr"]
spec.loader.exec_module(m)
m.SCORE_MD = score
lines = io.open(score, encoding="utf-8").read().split("\n")
hdr, rows, _ = m.find_table(lines)
print("OK rows=%d" % len(rows))
PY
)"; parse_rc=$?
if [ "$parse_rc" -ne 0 ]; then
    echo "⛔ REFUSES rc=2: .github/SCORE.md's standardized display cannot be read by util_score_row.py --"
    echo "   so every runner's row-write is failing RIGHT NOW, quietly, because gate_score_row is non-fatal"
    echo "   by design. This gate cannot measure and will not invent a verdict."
    printf '%s\n' "$parse_out" | tail -4 | sed 's/^/     /'
    gate_stamp 2>/dev/null || true
    exit 2
fi
printf '  ok   SCORE.md parses (%s)\n' "$parse_out"

echo "--- ARM 2 — no tracked .github file carries a column-zero conflict marker ---"
# Same narrow pattern and the same three exemptions as ../harness/scripts/lib_pre_commit_hook.txt, deliberately: two
# guards on one property must agree on what the property IS, or the pair has a seam a marker can live in.
EXEMPT="archive/ARCHIVE-ICON-JVM-HISTORY.md archive/ARCHIVE-MILESTONES.md archive/MILESTONE_ARCHIVE.md"
bad=""
while IFS= read -r f; do
    [ -n "$f" ] || continue
    case " $EXEMPT " in *" $f "*) continue ;; esac
    bad="$bad $f"
done < <(git -C "$GH" grep -l -a -E '^(<<<<<<< |>>>>>>> )' -- . 2>/dev/null)
if [ -z "$bad" ]; then
    ck ok "no tracked .github file carries a conflict marker (3 archives exempt by name)"
else
    for f in $bad; do
        ck fail "conflict marker in tracked .github file: $f"
        git -C "$GH" grep -a -n -E '^(<<<<<<< |>>>>>>> )' -- "$f" 2>/dev/null | head -3 | sed 's/^/       /'
    done
fi

echo "--- ARM 3 — the three archive exemptions still exist and still carry a marker ---"
# An exemption for a file that no longer needs it is a hole nobody is watching. If these stop carrying a
# marker, delete them from both lists rather than leaving a standing permission behind.
for ex in $EXEMPT; do
    if [ ! -f "$GH/$ex" ]; then
        ck fail "exempt file $ex no longer exists -- drop it from both exemption lists"
    elif git -C "$GH" grep -q -a -E '^(<<<<<<< |>>>>>>> )' -- "$ex" 2>/dev/null; then
        ck ok "exemption still earned: $ex"
    else
        ck fail "$ex no longer carries a marker -- the exemption is now an unwatched hole, drop it"
    fi
done

echo "--- ARM 4 — the two guards agree on the pattern and the exemptions ---"
# The hook and this gate are one property in two places; a seam between them is a place a marker lives.
HOOK="$HERE/lib_pre_commit_hook.txt"
if [ ! -f "$HOOK" ]; then ck fail "lib_pre_commit_hook.txt missing -- the authoring-time half is gone"
else
    hook_pat="$(grep -c "\^(<<<<<<< |>>>>>>> )" "$HOOK" 2>/dev/null || true)"
    [ "${hook_pat:-0}" -ge 1 ] && ck ok "hook uses the same column-zero pattern" \
                               || ck fail "hook's marker pattern has drifted from this gate's"
    miss=""
    for ex in $EXEMPT; do grep -q -- "$ex" "$HOOK" || miss="$miss $ex"; done
    [ -z "$miss" ] && ck ok "hook exempts the same three archives" \
                   || ck fail "hook is missing exemption(s):$miss -- the two guards disagree"
fi
GATE_EXAMINED="$examined"
gate_verdict "$violations" "violation(s)"
