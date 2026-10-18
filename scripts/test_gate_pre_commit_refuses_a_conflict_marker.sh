#!/usr/bin/env bash
# test_gate_pre_commit_refuses_a_conflict_marker.sh — the invariant gate for ARM 1 of the pre-commit hook
# (row `pre-commit-hook-refuses-a-staged-conflict-marker-in-any-tracked-file`, hq_C's mint, ceo CEO-370 rank 1).
#
# WHAT IT PROTECTS. A conflict marker committed to a shared authority does not fail where it was made -- it
# fails for every other seat, in a file they never touched. Measured 2026-09-06: a SCORE.md landed carrying
# markers, util_score_row.py could not parse the table, and THE LEADERBOARD WRITER WAS DEAD FOR AN HOUR WHILE
# EVERY BOARD STILL READ GREEN -- because a failed row-write is non-fatal BY DESIGN (gate_score_row), so that a
# bookkeeping failure never reds a board. Both decisions are right on their own and compose into a hole.
#
# ⛔ THE EXEMPTION ARM IS AS LOAD-BEARING AS THE REFUSAL ARM. Three tracked archives legitimately contain a
# marker as CONTENT (they archive a historical conflict). A guard that refuses those is a guard that gets
# bypassed with --no-verify, and a hook bypassed once is bypassed by habit. Both directions are graded here.
#
# ⛔ IT GRADES THE HOOK IN A SCRATCH REPO, never this one. A gate that stages files in the tree it is checking
# would leave a dirty index behind on a failure -- and it is precisely the failure path that must be safe.
#
# Usage: bash ../harness/scripts/test_gate_pre_commit_refuses_a_conflict_marker.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
SRC="$HERE/lib_pre_commit_hook.txt"
gate_require "$SRC" "the canonical pre-commit hook source lib_pre_commit_hook.txt"
violations=0; examined=0
ck() { examined=$((examined + 1)); if [ "$1" = ok ]; then printf '  ok   %s\n' "$2"; else printf '  FAIL %s\n' "$2"; violations=$((violations + 1)); fi; }
W="$(mktemp -d "${TMPDIR:-/tmp}/precommit_gate.XXXXXX")"; trap 'rm -rf "$W"' EXIT
# fresh scratch repo with the hook under test installed
newrepo() {
    rm -rf "$W/r"; mkdir -p "$W/r"; ( cd "$W/r" && git init -q . \
        && git config user.name LCherryholmes && git config user.email lcherryh@yahoo.com )
    cp "$SRC" "$W/r/.git/hooks/pre-commit"; chmod +x "$W/r/.git/hooks/pre-commit"
}
# try_commit -> prints the hook's rc; 0 means the commit was allowed
try_commit() { ( cd "$W/r" && git commit -q -m "gate probe" >/dev/null 2>&1; echo $? ); }

echo "--- ARM 1 — a staged conflict marker in an ordinary file is REFUSED ---"
newrepo
printf 'a\n<<<<<<< HEAD\nb\n=======\nc\n>>>>>>> other (subject)\nd\n' > "$W/r/doc.md"
( cd "$W/r" && git add doc.md )
[ "$(try_commit)" != 0 ] && ck ok "ordinary file with a marker refused" || ck fail "ordinary file with a marker was COMMITTED"

echo "--- ARM 2 — the three archive files are exempt BY NAME and still commit ---"
for ex in archive/ARCHIVE-ICON-JVM-HISTORY.md archive/ARCHIVE-MILESTONES.md archive/MILESTONE_ARCHIVE.md; do
    newrepo; mkdir -p "$W/r/archive"
    printf 'a\n<<<<<<< HEAD\nb\n=======\nc\n>>>>>>> other (subject)\nd\n' > "$W/r/$ex"
    ( cd "$W/r" && git add "$ex" )
    [ "$(try_commit)" = 0 ] && ck ok "exempt: $ex commits" || ck fail "exempt file $ex was REFUSED"
done

echo "--- ARM 3 — a clean file is untouched (the guard convicts the commit in front of it, nobody else) ---"
newrepo; printf 'perfectly ordinary\n' > "$W/r/clean.md"; ( cd "$W/r" && git add clean.md )
[ "$(try_commit)" = 0 ] && ck ok "clean file commits" || ck fail "clean file was REFUSED"

echo "--- ARM 4 — THE CASE THAT MATTERS: worktree RESOLVED, index still CONFLICTED ---"
# The hook must read the STAGED BLOB, not the file on disk. Staging a conflicted file and then fixing the
# worktree is exactly how a marker reaches origin while the author's own editor looks clean.
newrepo
printf 'a\n<<<<<<< HEAD\nb\n=======\nc\n>>>>>>> other (subject)\nd\n' > "$W/r/two.md"
( cd "$W/r" && git add two.md )
printf 'a\nb\nd\n' > "$W/r/two.md"                     # worktree now clean; INDEX still carries the marker
[ "$(try_commit)" != 0 ] && ck ok "conflicted INDEX refused even though the worktree is clean" \
                          || ck fail "read the worktree instead of the index -- a marker would reach origin"

echo "--- ARM 5 — a marker in a NUL-bearing file is still detected ---"
# corpus/tests/snobol4/ALL.ref carries one NUL byte (a legitimate CHAR(0) witness), so a marker there must
# still be found. ⛔⭐ THIS ARM ASSERTS THE PROPERTY, AND IT DOES NOT PROVE THE `-a` FLAG -- I checked, and
# saying so is the point. Measured 2026-09-06: this box's INTERACTIVE shell defines `grep` as a FUNCTION
# routing to ugrep 7.8.4, while scripts and hooks resolve /usr/bin/grep, GNU grep 3.11. On a NUL-bearing
# file they DISAGREE: ugrep answers rc=1 without -a and rc=0 with it; GNU grep answers rc=0 either way.
# So ablating -a from the hook leaves this arm green -- not because the arm is weak, but because the hook
# runs under the grep that does not need it. `-a` stays in the hook as the portable form; this arm grades
# the behaviour we actually require, which is the honest thing an arm can claim.
# ⭐ THE GENERAL RESULT IS WORTH MORE THAN THE ARM: a claim measured in the interactive shell and relied on
# in a script is a claim measured with a DIFFERENT TOOL, silently. That is the real cause behind the
# fleet's "grep is blind to ALL.ref" lesson, which has been carried for weeks without a cause attached.
newrepo
printf 'a\000b\n<<<<<<< HEAD\nb\n=======\nc\n>>>>>>> other (subject)\nd\n' > "$W/r/withnul.ref"
( cd "$W/r" && git add withnul.ref )
[ "$(try_commit)" != 0 ] && ck ok "NUL-bearing file with a marker refused" \
                          || ck fail "a NUL byte hid the marker -- the hook cannot see into ALL.ref-shaped files"

echo "--- ARM 6 — a bare '=======' alone does NOT refuse (it is the markdown setext H2 underline) ---"
# Deliberate and measured: zero tracked files across all three repos carry a bare ^=======$ today, and git
# writes all three markers together, so the two angle forms already catch every real conflict. Matching it
# would plant a permanent false positive in every document for no detection gain -- and a guard that cries
# wolf gets bypassed, after which it guards nothing.
newrepo; printf 'A heading\n=======\nbody text\n' > "$W/r/setext.md"; ( cd "$W/r" && git add setext.md )
[ "$(try_commit)" = 0 ] && ck ok "markdown setext underline is not a conflict" \
                        || ck fail "a legitimate '=======' underline was refused"

echo "--- ARM 7 — ARM 2 of the hook (src/ comments) still fires: this change must not have eaten it ---"
newrepo; mkdir -p "$W/r/src" "$W/r/scripts"
cp "$HERE/strip_comments.py" "$W/r/scripts/strip_comments.py" 2>/dev/null || true
printf 'int f(void) { return 0; }\n/* a comment that src/ forbids */\n' > "$W/r/src/a.c"
( cd "$W/r" && git add src/a.c )
if [ -f "$W/r/scripts/strip_comments.py" ]; then
    [ "$(try_commit)" != 0 ] && ck ok "src/ comment arm still refuses" || ck fail "the src/ comment arm stopped firing"
else
    ck ok "src/ comment arm not gradable here (strip_comments.py absent) -- reported, not skipped-as-pass"
fi

echo "--- ARM 8 — the INSTALLED hooks match the tracked source in every sibling repo ---"
for r in SCRIP corpus .github; do
    h="$ROOT/../$r/.git/hooks/pre-commit"
    if [ ! -f "$h" ]; then ck fail "$r has no pre-commit hook installed"
    elif cmp -s "$SRC" "$h"; then ck ok "$r hook == tracked source"
    else ck fail "$r hook DIFFERS from lib_pre_commit_hook.txt -- run ../harness/scripts/install_commit_msg_hook.sh"; fi
done
GATE_EXAMINED="$examined"
gate_verdict "$violations" "violation(s)"
