#!/bin/bash
# test_gate_icon_scratch_names_are_not_tracked.sh -- the Icon scratch names (tmp1..tmp4) are IGNORED at the
# repo root and TRACKED NOWHERE, and no suite writes them into the source tree.
#
# ⛔⭐ THE MEASURED CASE (hq_I, 2026-09-13; landed by hq_B under CONCERN 5). SCRIP/.gitignore listed `tmp1`
# and `/tmp3` and NOT tmp2, NOT tmp4 -- while corpus/packages/icon/{arizona,jcon}_tests write all four
# (io.icn opens tmp1/tmp2 "w"; iobig.icn testio()s tmp3/tmp4). A stray 400KB tmp4 left by a suite run hq_I
# did not make turned their handoff banner ⛔ FAILURE on a sitting whose work was entirely pushed.
# ⭐ hq_I'S SENTENCE IS THE REUSABLE HALF: an ignore list that covers SOME of a generated set is worse than
# one that covers none, because the covered members train you to believe the set is handled. tmp1 and tmp3
# being ignored is exactly why nobody looked for tmp2 and tmp4.
#
# ⛔⭐⭐ WHY A GATE AND NOT JUST FOUR IGNORE LINES, WHICH IS THE WHOLE POINT OF THIS FILE. The suites' own
# comment already argues against ignoring: "ignoring the name silences the symptom while a test still writes
# into the source tree". Both automated writers ARE cured -- test_icon_all_rungs runs from ICN_SCRATCH
# (2026-08-30) and test_icon_arizona_suite snapshots each test dir and deletes what appeared (2026-09-04) --
# so the four ignore lines now cover only the HAND RUN, a human grading a program from the repo root. That is
# a mess, not a defect. ⛔ BUT AN IGNORED NAME IS INVISIBLE TO `git status` BY DESIGN, so the day a suite
# starts writing into the tree again, the ignore list is exactly what guarantees nobody notices. The ignore
# handles the human; THIS handles the regression. Neither one can do the other's job.
#
# ⛔ THE ARM THAT MATTERS MOST IS (2), TRACKEDNESS. handoff_status.sh says "commit them" about untracked
# output, and the obvious reading of that sentence is to COMMIT a 400KB generated artifact -- tmp3 was
# committed by accident once already and the ceo deleted it. A wrong instruction plus a plausible file is
# how generated output gets into a source repo, and it only has to succeed once.
#
# THE THREE EXIT CODES: 0 clean · 1 violation · 2 could-not-measure. Never skip-as-success.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_subject_tree.sh"
REPO="$(s4e_subject_repo "${BASH_SOURCE[0]}")"
ROOT="$(s4e_subject_root "$REPO")"
NAMES="${ICON_SCRATCH_NAMES:-tmp1 tmp2 tmp3 tmp4}"
GI="${ICON_SCRATCH_GITIGNORE:-$REPO/.gitignore}"
command -v git >/dev/null || { echo "⛔ REFUSES rc=2: no git -- trackedness is the arm that matters and it cannot be checked."; exit 2; }
[ -r "$GI" ] || { echo "⛔ REFUSES rc=2: cannot read $GI"; exit 2; }

echo "icon scratch names -- recomputed live, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
s4e_subject_announce "$REPO" >/dev/null || true
echo "  names: $NAMES"
FAIL=0; N=0

# ── ARM 1: the ignore list covers EVERY name, root-anchored, or none of the promise holds. ─────────────────
MISS=""
for n in $NAMES; do
    N=$((N+1))
    grep -qE "^/?$n\$" "$GI" || MISS="$MISS $n"
done
if [ -n "$MISS" ]; then
    echo "⛔ ASYMMETRIC IGNORE LIST -- these are written by the same programs as the ones it does cover:$MISS"
    echo "     -> the covered members train a reader to believe the set is handled. Cover all $N or none."
    FAIL=1
else
    echo "  ✅ arm 1: all $N scratch name(s) are ignored at the repo root"
fi

# ── ARM 2: NONE of them is tracked, in EITHER repo. This is the one that stops a 400KB artifact landing. ──
TRACKED=""
for r in "$REPO" "$ROOT/corpus"; do
    [ -d "$r/.git" ] || [ -f "$r/.git" ] || continue
    for n in $NAMES; do
        while IFS= read -r f; do [ -n "$f" ] && TRACKED="$TRACKED $(basename "$r")/$f"; done <<EOF
$(git -C "$r" ls-files "$n" "*/$n" 2>/dev/null)
EOF
    done
done
TN=$(printf '%s' "$TRACKED" | wc -w)
# ⛔⭐ A RATCHET, NOT A BLOCK, AND THE REASON IS NAMED RATHER THAN ASSUMED. This arm found FOUR on its first
# run -- tmp3 and tmp4 under packages/icon/{arizona_tests/general,jcon_tests}, 1.6 MB of generated output
# vendored into the corpus repo at aa4bb4238 (2026-09-11). They are OUTPUT, not fixtures: iobig.icn's
# `testio("tmp3","t",read,write,create textgen())` CREATES them, and their content is textgen()'s own
# `0\n1\n2\n...`. ⛔ Deleting vendored files under packages/icon belongs to the seat that owns the Icon
# packages, not to whoever happened to write this gate, so it is NAMED and ratcheted instead of cured here
# (CEO-669: a change to a node another concern owns is an ASK with the measurement, never a landing).
# ⭐ THE RATCHET IS THE HONEST MIDDLE: the count may only fall, so the defect cannot grow while the ruling is
# outstanding, and a green gate never has to mean "there is nothing here".
TCEIL="${ICON_SCRATCH_TRACKED_CEILING:-0}"
if [ "$TN" -gt "$TCEIL" ]; then
    echo "⛔ RATCHET BROKEN: $TN tracked scratch file(s) > ceiling $TCEIL -- generated output was ADDED:$TRACKED"
    echo "     -> git rm --cached it. handoff_status.sh says \"commit them\" about untracked output, and"
    echo "        following that advice for these names is exactly how this happens; tmp3 landed that way once."
    FAIL=1
elif [ "$TN" -gt 0 ]; then
    echo "  ⚠️  arm 2 REPORTED (ratchet $TN/$TCEIL, may only fall): generated output is tracked in corpus --$TRACKED"
    echo "      1.6 MB of testio() output vendored at aa4bb4238. Owned by the Icon-packages seat; ASKed, not"
    echo "      cured here. Lower the ceiling in the commit that removes them."
else
    echo "  ✅ arm 2: none of the scratch names is tracked in SCRIP or corpus"
fi

# ── ARM 3: the two structural cures are still in place. ⭐ THIS IS WHAT MAKES ARM 1 SAFE: ignoring a name is
# only defensible while nothing automated writes it, so the gate pins the cures rather than trusting them. ──
RUNGS="$REPO/../harness/scripts/test_icon_all_rungs.sh"; ARIZ="$REPO/../harness/scripts/test_icon_arizona_suite.sh"
CURES=0; LOST=""
if [ -r "$RUNGS" ]; then CURES=$((CURES+1)); grep -q 'tdir="\$ICN_SCRATCH"' "$RUNGS" || LOST="$LOST test_icon_all_rungs(scratch-cwd)"; fi
if [ -r "$ARIZ" ];  then CURES=$((CURES+1)); grep -q 'PRESNAP_FILE' "$ARIZ" && grep -q 'rm -f -- "\$PKG/\$new"' "$ARIZ" || LOST="$LOST test_icon_arizona_suite(snapshot-cleanup)"; fi
if [ "$CURES" -lt 2 ]; then
    echo "⛔ REFUSES rc=2: found $CURES of 2 Icon suite runners -- cannot say whether the tree is still protected."
    echo "   A renamed or absent runner is not evidence that nothing writes into the tree."
    exit 2
fi
if [ -n "$LOST" ]; then
    echo "⛔ A STRUCTURAL CURE IS GONE:$LOST"
    echo "     -> with the names ignored, a suite writing into the tree again is INVISIBLE to git status."
    echo "        Restore the cure, or stop ignoring the names -- but never neither."
    FAIL=1
else
    echo "  ✅ arm 3: both Icon suites still keep their writes out of the source tree"
fi

# ── REPORTED: residue present but ignored. Not a failure -- a human's hand run is a mess, not a defect. ────
RES=""
for n in $NAMES; do [ -e "$REPO/$n" ] && RES="$RES $n"; done
[ -n "$RES" ] && { echo "  ⚠️  residue in this root (ignored, harmless, yours to delete):$RES"; echo "      it is regenerable test output -- delete it, never commit it."; }

[ "$FAIL" -ne 0 ] && { echo "⛔ GATE FAILED"; exit 1; }
# ⛔ THE VERDICT LINE STATES THE RATCHET RATHER THAN ROUNDING IT TO "clean". It read "tracked nowhere" while
# arm 2 was reporting four tracked files three lines above -- a summary that contradicts its own body, which
# is the shape every reader trusts and nobody re-reads. A green gate with a standing debt must say the debt.
if [ "$TN" -gt 0 ]; then
    echo "✅ GATE OK -- $N name(s) ignored, both suites write elsewhere; $TN tracked file(s) STILL OUTSTANDING (ratchet $TN/$TCEIL, ASKed)"
else
    echo "✅ GATE OK -- $N scratch name(s) ignored, tracked nowhere, and both suites still write elsewhere"
fi
exit 0
