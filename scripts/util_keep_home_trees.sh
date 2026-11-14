#!/usr/bin/env bash
# util_keep_home_trees.sh -- KEEP THE FLEET'S SHARED TREES AT ORIGIN: /home/corpus, /home/harness and /home/.github, fast-forward only (the grader
# 2026-11-13; Lon 18:0x CST, in the coo's window, verbatim: "So I'm creating /home/corpus and /home/harness for the ENTIRE FLEET to share. So get those
# scripts fixed. And GRADER is in charge and gets a /loop too."; 18:1x: .github leaves the roots too, at /home/.github). Each is a full clone of
# origin that borrows its objects from the coo root (git clone --reference /home/claude_coo/<repo>), made by the grader that day. A cron line runs this
# every minute and the grader's loop each tick; one run at a time (flock). This never clones: a tree that is missing refuses rc 2, and a re-clone goes to a
# temp name beside the tree and is renamed into place, so no reader sees half a tree (the coo 2026-11-13 18:3x CST, on officer_02's red re-gate). A change lands through s4e_land.sh, never here: a tree that holds a tracked
# change or a commit origin lacks is NAMED and left as it is, never reset, stashed or discarded (skill seat-conduct 2). Quiet when nothing moved.
#   bash util_keep_home_trees.sh            rc 0 every tree at origin; 1 a tree left as it is (named); 2 cannot measure (not a clone, fetch failed)
set -u
TOP="${S4E_HOME_TREES_TOP:-/home}"; LOCK="${S4E_HOME_TREES_LOCK:-/home/resources/progress/HOME-TREES.lock}"
now() { date -u +%FT%TZ; }
exec 9> "$LOCK" || { echo "$(now) REFUSE(2) cannot open $LOCK"; exit 2; }
flock -n 9 || exit 0   # another keeper run holds it: that run keeps the trees
# THE LOCK IS ALSO THE MAINTENANCE WINDOW (the grader 2026-11-13, row harness-one-disk-step-6-the-cutover): a step that rewrites a kept repo's objects (a repack,
# an alternates file written or removed, the store below made or re-pointed) runs whole under this lock, flock /home/resources/progress/HOME-TREES.lock <cmd>,
# so the keeper never fetches into a repo mid-repack; it skips each minute the lock is held and keeps again at the first minute after.
rc=0
for r in corpus harness .github; do
    d="$TOP/$r"
    [ -d "$d/.git" ] || { echo "$(now) REFUSE(2) $d is not a clone"; rc=2; continue; }
    if [ -n "$(git -C "$d" status --porcelain --untracked-files=no 2>/dev/null)" ]; then echo "$(now) LEFT $d: it holds tracked changes (named, never discarded)"; [ $rc = 0 ] && rc=1; continue; fi
    b="$(git -C "$d" rev-parse --short=10 HEAD)"
    timeout -k 5 120 git -C "$d" fetch -q origin main 2>/dev/null || { echo "$(now) REFUSE(2) $d: fetch of origin main failed"; rc=2; continue; }
    if git -C "$d" merge -q --ff-only origin/main 2>/dev/null; then
        a="$(git -C "$d" rev-parse --short=10 HEAD)"; [ "$a" = "$b" ] || echo "$(now) KEEP $r $b..$a"
    else
        echo "$(now) LEFT $d: not a fast-forward of origin/main (a commit origin lacks; named, never discarded)"; [ $rc = 0 ] && rc=1
    fi
done
# THE ONE OBJECT STORE (row harness-one-disk-step-6-the-cutover step 2, officer_02; the coo 2026-11-13 20:5x CST: "a bare /home/SCRIP.git object store that every root's
# SCRIP borrows from instead of the coo root. Your keeper keeps that one at origin too."): every root's SCRIP borrows objects from it, so nothing is ever deleted
# from it: each fetch runs with gc and auto-maintenance off and never prunes a ref, and no keeper run repacks it. Absent or an empty folder (Lon made it empty at
# 20:53; officer_02 fills it as a bare clone, under the lock above): not made yet, skipped quietly. The store is named by --git-dir, never found by a search upward.
S="$TOP/SCRIP.git"
if [ -d "$S" ] && [ -n "$(ls -A "$S" 2>/dev/null)" ]; then
    if [ "$(git --git-dir="$S" rev-parse --is-bare-repository 2>/dev/null)" != true ]; then echo "$(now) REFUSE(2) $S is not a bare repository"; rc=2
    else
        b="$(git --git-dir="$S" rev-parse --short=10 refs/heads/main 2>/dev/null || echo none)"
        if timeout -k 5 300 git --git-dir="$S" -c gc.auto=0 -c maintenance.auto=false fetch -q --no-prune origin '+refs/heads/*:refs/heads/*' 2>/dev/null; then
            a="$(git --git-dir="$S" rev-parse --short=10 refs/heads/main 2>/dev/null || echo none)"; [ "$a" = "$b" ] || echo "$(now) KEEP SCRIP.git $b..$a"
        else
            echo "$(now) REFUSE(2) $S: fetch of origin's heads failed"; rc=2
        fi
    fi
fi
# THE ONE COPY OF THE SKILLS (row harness-the-skills-live-once-in-the-users-claude-skills, officer_06 2026-11-13): once a human has installed the user-level copy
# (propagate_skills.sh --user writes its manifest, the switch), every run refreshes it from $TOP/.github/skills when it differs; before that it writes nothing.
_man="${S4E_SKILLS_MANIFEST:-$HOME/.claude/s4e-skills.manifest}"
if [ -f "$_man" ] && [ -f "$TOP/harness/scripts/propagate_skills.sh" ]; then
    if ! S4E_PROPAGATE_FETCHED=1 bash "$TOP/harness/scripts/propagate_skills.sh" --user --check >/dev/null 2>&1; then
        # the refresh's own status, never a pipe's (no pipefail here: "$(... | tail -1)" read tail's 0, so a failed refresh printed KEEP; the grader 2026-11-13)
        o="$(S4E_PROPAGATE_FETCHED=1 bash "$TOP/harness/scripts/propagate_skills.sh" --user 2>&1)"; prc=$?; o="${o##*$'\n'}"
        if [ $prc = 0 ]; then echo "$(now) KEEP skills: $o"; else echo "$(now) LEFT skills: rc=$prc $o"; [ $rc = 0 ] && rc=1; fi
    fi
fi
exit $rc
