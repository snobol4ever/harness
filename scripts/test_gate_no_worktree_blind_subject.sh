#!/bin/bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_no_worktree_blind_subject.sh -- CENSUSES THE WORKTREE-BLIND SUBJECT IDIOM, and REFUSES rc=2 when the
# tree it is standing in is not the tree that idiom would have graded.
#
# ⛔⭐ THE MEASURED CASE (the coo, 2026-09-13, reported against its OWN landing -- row
# snobol4-a-gate-that-reads-the-main-tree-src-passes-in-a-worktree-while-origin-is-red).  A pre-landing
# preflight run in a second worktree read 33 arms 0 red WHILE ORIGIN WAS RED for about thirty-five minutes
# after f0d0adf5b landed a weak pas_gc_roots.  Nothing was skipped and nothing lied: every arm ran, and every
# arm graded the MAIN checkout instead of the worktree being pushed.
#
# ⛔ THE IDIOM, WHICH IS WHAT THIS GATE COUNTS.  Two hops, of which the first is correct:
#       S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"    # UP  -- right, siblings live there
#       SRC="$S4E/SCRIP/src" ; SCRIP="$S4E/SCRIP/scrip" ; OUT="$S4E/SCRIP/out"    # DOWN -- WRONG, hardcoded name
# `SCRIP` is the name of the MAIN checkout and of nothing else, so the round trip lands in the tree you are not
# standing in.  ⭐ NOTE WHAT THE SECOND HOP REACHES BESIDES src: `$S4E/SCRIP/scrip` is the main tree's BINARY.
# A gate written that way grades a binary the seat never built, which is the same defect with a longer fuse --
# you can `make` in your worktree all day and the gate will keep grading the other build.
#
# ⭐ WHY THE CENSUS IS THE DELIVERABLE AND NOT A ONE-LINE FIX.  The idiom is not a typo anyone committed once;
# it is the house pattern, pasted forward.  A cure applied to the one gate that was caught leaves the class
# intact and leaves the next seat with the same thirty-five minutes.  So this gate names every instance, and it
# names them by reading the scripts on disk rather than from a list anyone maintains by hand -- a hard-coded
# population never announces what it left out.
#
# ⛔ IT IS REPORTED-NOT-BLOCKING TODAY, ON PURPOSE AND WITH A RAMP.  The population is large and curing it is a
# per-script judgement (some of these legitimately want a sibling, and telling the two apart needs a reader).
# A gate that blocked on the whole class today would stop the very landings that shrink it.  What IS blocking:
# the RATCHET -- the count may never grow -- and the DIVERGENCE REFUSAL below, which is the part that actually
# protects a verdict.  Set WORKTREE_BLIND_BLOCKING=1 to prove it can say no.
#
# THE THREE EXIT CODES (lib_gate.sh's rule): 0 clean · 1 violation · 2 could-not-measure.  Never skip-as-success.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_subject_tree.sh"
REPO="$(s4e_subject_repo "${BASH_SOURCE[0]}")"
SCRIPTS="$REPO/../harness/scripts"
[ -d "$SCRIPTS" ] || { echo "⛔ REFUSES rc=2: no ../harness/scripts/ under $REPO -- cannot census what it cannot see."; exit 2; }
command -v grep >/dev/null || { echo "⛔ REFUSES rc=2: no grep"; exit 2; }

# ── `--prove`: THE REPRODUCTION, EXECUTABLE, SO THE EVIDENCE IS NOT A TRANSCRIPT. ────────────────────────────
# ⛔⭐ WHY THIS IS IN THE GATE AND NOT IN A FINDING. The whole defect is that a verdict can be about a tree
# nobody checked, and the cure is only believable if you can WATCH it fail the old way and pass the new way.
# A pasted terminal session proves that once, on a tree that has since moved; TRANSCRIPTION IS WHERE PROVENANCE
# DIES. This arm mints a real sibling worktree, arms its src with a weak stub the main checkout does NOT have,
# and asserts BOTH halves: the OLD idiom reports the armed tree clean, and the CURED gate fails on it.
# ⛔ It asserts the OLD behaviour too, on purpose. A fail-once proof that only exercises the fix cannot tell a
# working cure from a defect that was never there -- and this defect is invisible by construction.
if [ "${1:-}" = "--prove" ]; then
    command -v git >/dev/null || { echo "⛔ REFUSES rc=2: no git -- the reproduction needs a worktree."; exit 2; }
    git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { echo "⛔ REFUSES rc=2: $REPO is not a git checkout."; exit 2; }
    W="$(mktemp -d)"; SIB="$W/SCRIP-wt"
    # ⭐ The worktree must be a SIBLING of a directory literally named SCRIP, because that is the shape the bug
    # needs: the up-and-back-down round trip only lands somewhere else when `<root>/SCRIP` exists and is a
    # DIFFERENT tree. A worktree parked anywhere else resolves to nothing and the old code honestly refuses --
    # which is why this went unnoticed for so long, and why the proof has to reconstruct the shape exactly.
    mkdir -p "$W/SCRIP/src" "$W/harness/scripts"
    git -C "$REPO" worktree add --detach "$SIB" HEAD >/dev/null 2>&1 || { rm -rf "$W"; echo "⛔ REFUSES rc=2: could not mint a worktree."; exit 2; }
    printf '\nvoid __attribute__((weak)) prove_worktree_blind_stub(void) { }\n' >> "$SIB/src/runtime/rt/zeta_alloc.c"
    PRC=0
    # HALF A -- the OLD idiom, reconstructed in four lines, reading the armed tree as clean.
    OLD_S4E="$(cd "$SIB/../.." 2>/dev/null && pwd)"; OLD_SRC="$SIB/../SCRIP/src"
    OLDHITS=$(grep -rn '__attribute__((weak))' "$OLD_SRC" --include=*.c --include=*.h 2>/dev/null | grep -c . || true)
    if [ "$OLDHITS" -eq 0 ]; then
        echo "  ✅ prove A: the OLD idiom resolved to $(cd "$OLD_SRC" && pwd) and found the armed stub NOWHERE -- a green verdict about the wrong tree."
    else
        echo "  ⛔ prove A FAILED: the old idiom saw the armed stub; the reproduction did not reconstruct the defect."; PRC=1
    fi
    # HALF B -- the CURED gate, run from inside the armed worktree, must fail rc=1 and name the worktree's file.
    cp "$SCRIPTS/lib_subject_tree.sh" "$SCRIPTS/test_gate_no_weak_abort_stub.sh" "$W/harness/scripts/" 2>/dev/null
    NEWOUT="$(cd "$SIB" && bash ../harness/scripts/test_gate_no_weak_abort_stub.sh 2>&1)"; NEWRC=$?
    if [ "$NEWRC" -eq 1 ] && printf '%s' "$NEWOUT" | grep -q "$SIB/src"; then
        echo "  ✅ prove B: the CURED gate failed rc=1 in the worktree and named $SIB/src -- it graded the tree it was run from."
    else
        echo "  ⛔ prove B FAILED: cured gate rc=$NEWRC, and the output did not name the worktree's src:"; printf '%s\n' "$NEWOUT" | sed 's|^|       |'; PRC=1
    fi
    git -C "$REPO" worktree remove --force "$SIB" >/dev/null 2>&1; rm -rf "$W"; git -C "$REPO" worktree prune >/dev/null 2>&1
    [ "$PRC" -eq 0 ] && echo "✅ PROVEN: the defect reproduces on the old idiom and does not survive the cure." || echo "⛔ PROOF FAILED"
    exit "$PRC"
fi

echo "worktree-blind subject gate -- recomputed live, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
s4e_subject_announce "$REPO"; DIVERGED=$?

# ── ARM 1 (BLOCKING): THE DIVERGENCE REFUSAL. ─────────────────────────────────────────────────────────────────
# ⭐ This is the arm that does the protecting, and it is deliberately the cheapest thing in the file.  If the
# tree this gate lives in is NOT the tree the hardcoded name resolves to, then every uncured instrument in this
# checkout is right now grading the other one, and no verdict from this run means what it appears to mean.
# ⛔ It refuses rather than failing: "these gates are about to grade the wrong tree" is not a defect IN the tree
# being graded, and spelling it rc=1 would make a worktree look like it had a bug in it.
if [ "$DIVERGED" -ne 0 ]; then
    echo "⛔ REFUSES rc=2: the subject tree and the hardcoded-name target are DIFFERENT TREES (named above)."
    echo "   Any gate in this checkout still using the up-and-back-down idiom is grading the other one."
    echo "   This is NOT a pass and NOT a failure of this tree: it is a verdict that cannot be trusted to be"
    echo "   about this tree.  Run the blocking set from the main checkout, or cure the instruments first."
    exit 2
fi

# ── ARM 2 (RATCHET, BLOCKING): the count may never grow. ──────────────────────────────────────────────────────
# ⛔ ANTI-VACUITY FIRST.  A census whose pattern has stopped matching reports a triumphant zero.  So the floor is
# not 0: this gate knows roughly how large the class is, and a sudden collapse to nothing is a broken pattern,
# not a finished campaign.  Same lesson lib_gate.sh learned when a stray \? matched 1 site of 17 and read green.
# ⛔⭐ THE CENSUS READS CODE, NEVER COMMENTS -- AND THIS GATE WAS TWO OF ITS OWN 69 (hq_B 2026-09-13, on hq_C's
# flag that preflight read 39 of 40 on a clean origin/main with nobody's diff behind the red). A `grep -rl`
# matches the string ANYWHERE in a file, so the two files that exist to CURE this idiom -- lib_subject_tree.sh
# and this gate -- were counted as instances of it, because both QUOTE the bad two hops in their own teaching
# comments. ⭐ THAT IS NOT A COSMETIC MISCOUNT, IT IS AN UNREACHABLE FLOOR: the refusal a dozen lines below
# says a finished campaign "would have been landed with the ceiling lowered to 0 in the same commit", and with
# the cure's own documentation permanently inside the count, 0 was arithmetically impossible to reach. A
# ratchet that can never close is a ratchet nobody can finish.
# ⛔ Measured at the cure: 69 matches = 67 genuine code instances + exactly these 2 comment-only mentions.
BLIND_FILES=$(grep -rnE '\$\{?S4E\}?/SCRIP/|\$\{?ROOT\}?/SCRIP/' "$SCRIPTS" 2>/dev/null \
              | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | cut -d: -f1 | sort -u || true)
BLIND=$(printf '%s' "$BLIND_FILES" | grep -c . || true)
GATES=$(printf '%s\n' "$BLIND_FILES" | grep -c '/test_gate_' || true)
TOTAL=$(ls "$SCRIPTS" | grep -c . || true)
CEILING="${WORKTREE_BLIND_CEILING:-66}"       # ⛔ MEASURED, never estimated: 66 on 2026-09-13 by hq_B, on THIS tree, with the comment-only mentions excluded above and test_gate_banner_prints_a_verdict_word_and_a_ruled_grid.sh cured in the same commit. Was 68 at 202d8bfff under the old comment-blind pattern (69 by the time hq_C hit it). ⛔ RE-CUT DOWNWARD, NEVER UP: the 69th was a real new instance and the cure was to remove it, not to make room for it -- a ceiling raised to admit the instance that broke it is not a ratchet, it is a rubber stamp with extra steps.
FLOOR="${WORKTREE_BLIND_FLOOR:-1}"

echo "  census: $BLIND of $TOTAL script(s) resolve a subject through the hardcoded name \`SCRIP/\` ($GATES of them are test_gate_*)"
if [ "$BLIND" -lt "$FLOOR" ]; then
    echo "⛔ REFUSES rc=2: the census matched $BLIND, below the floor of $FLOOR."
    echo "   A campaign that finished would have been landed with the ceiling lowered to 0 in the same commit."
    echo "   An unannounced zero is a pattern that stopped matching, and it reports as success. Fix the pattern."
    exit 2
fi
RC=0
if [ "$BLIND" -gt "$CEILING" ]; then
    echo "⛔ RATCHET BROKEN: $BLIND > ceiling $CEILING -- a NEW worktree-blind subject was added."
    echo "   Derive the subject from the script's own location (../harness/scripts/lib_subject_tree.sh), not from \$S4E/SCRIP."
    RC=1
fi

# ── ARM 3 (REPORTED, NOT BLOCKING): name the population, so the cure is a list and not an archaeology project. ─
echo "  ── the population, so it can be worked down rather than rediscovered ──"
printf '%s\n' "$BLIND_FILES" | grep '/test_gate_' | sed "s|^$REPO/|     |" | head -60
EXTRA=$((GATES > 60 ? GATES - 60 : 0))
[ "$EXTRA" -gt 0 ] && echo "     ... and $EXTRA more test_gate_* (the full list is the grep above, not this printout)"
echo "     non-gate scripts with the same idiom: $((BLIND - GATES))  (runners, boards and utils -- same hazard, same cure)"

if [ "${WORKTREE_BLIND_BLOCKING:-0}" = "1" ] && [ "$BLIND" -gt 0 ]; then
    echo "⛔ WORKTREE_BLIND_BLOCKING=1: $BLIND uncured instrument(s) -- failing to prove this gate can say no."
    exit 1
fi
[ "$RC" -ne 0 ] && { echo "⛔ GATE FAILED"; exit 1; }
echo "✅ GATE OK -- subject derived from this script's own location; census $BLIND at or under ceiling $CEILING"
exit 0
