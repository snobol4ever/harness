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
# THE ONE COPY OF THE SKILLS (row harness-the-skills-live-once-in-the-users-claude-skills, officer_06 2026-11-13): once a human has installed the user-level copy
# (propagate_skills.sh --user writes its manifest, the switch), every run refreshes it from $TOP/.github/skills when it differs; before that it writes nothing.
_man="${S4E_SKILLS_MANIFEST:-$HOME/.claude/s4e-skills.manifest}"
if [ -f "$_man" ] && [ -f "$TOP/harness/scripts/propagate_skills.sh" ]; then
    if ! S4E_PROPAGATE_FETCHED=1 bash "$TOP/harness/scripts/propagate_skills.sh" --user --check >/dev/null 2>&1; then
        o="$(S4E_PROPAGATE_FETCHED=1 bash "$TOP/harness/scripts/propagate_skills.sh" --user 2>&1 | tail -1)" && echo "$(now) KEEP skills: $o" || { echo "$(now) LEFT skills: $o"; [ $rc = 0 ] && rc=1; }
    fi
fi
exit $rc
