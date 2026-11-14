#!/usr/bin/env bash
# populate_numbered_seat.sh NN [--from ROOT] -- ONE NUMBERED HAIKU SEAT IN ONE COMMAND (the cio, 2026-11-05; Lon 15:1x CST: "rename them all 01, 02,
# ..., 20. Because there are no longer any specialties seats. We have skills now instead use by ANY ASSIGNED seat. Make it so."). Lon creates the folder
# /home/claude_worker_NN (/home is root's); this fills it: the four repos cloned --shared from the coo root (its objects borrowed, origin set
# to github; corpus, harness and .github then linked to the shared pristine), the FULL corpus (the coo 2026-11-12 18:0x, on junior_13's measurement: a sparse
# root hid corpus/demos and every demos suite listed 0 members there; sparse is for worktrees only, s4e_worktree.sh; the links make it cost nothing), the Stop banner and inbox hooks and the skill gate named for the seat (from the source root's .claude, seat and root substituted),
# banner_compact.py, /tmp/s4e/worker_NN, the postoffice mailbox (inbox archive, HQ file naming cio), and the worker digest (propagate_seat_digests_cto_484.py).
# It does NOT touch ROSTER, FLEET or the old seat's rows: the cio adds the seat to ROSTER and reowns the retired HQ's rows in the same sitting, by hand, measured.
# rc 0 populated (prints the root's du); 1 refused (no folder, folder not empty, no source root); 2 usage.
set -uo pipefail
# THE NEW LAYOUT SUPERSEDES THE HEADER'S FOUR REPOS (the cio 2026-11-14, row harness-one-disk-step-6-the-cutover; Lon, in the cio's window, verbatim: "We are meant not
# to have folder .github, harness, and corpus in each /home/claude folder, but they have not been cleaned out. Complete the new disk/file layout."): a seat root is
# its SCRIP clone, .claude and CLAUDE.md, nothing else. SCRIP borrows its objects from the one store /home/SCRIP.git (the grader's keeper keeps it at origin); corpus,
# harness and .github are read from /home/corpus, /home/harness and /home/.github (lib_paths.sh), and this script runs from /home/harness.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; STORE="${S4E_SCRIP_STORE:-/home/SCRIP.git}"; GH="${S4E_GITHUB:-/home/.github}"
NN="${1:-}"; FROM=/home/claude_cio; [ "${2:-}" = --from ] && FROM="${3:?--from ROOT}"
# grader: the grade workers own root, which nothing but the controller syncs and builds (the coo 2026-11-07 16:23: a cio landing rebuilt the binary under job 1221)
case "$NN" in [0-9][0-9]) seat="junior_$NN";; junior_[0-9][0-9]|officer_[0-9][0-9]|senior_[0-9][0-9]|grader) seat="$NN";; *) echo "usage: populate_numbered_seat.sh NN|officer_NN|senior_NN [--from ROOT]  (NN two digits: the seat is worker_NN; a named numbered seat is itself; Lon 2026-11-07 15:4x: the Opus designers and Sonnet seniors)"; exit 2;; esac
root="/home/claude_$seat"; PO=/home/resources/postoffice
[ -d "$root" ] || { echo "REFUSE(1): $root does not exist -- Lon creates the folder (/home is root's)"; exit 1; }
[ -z "$(ls -A "$root")" ] || { echo "REFUSE(1): $root is not empty -- this script fills an empty folder only"; exit 1; }
[ "$(git --git-dir="$STORE" rev-parse --is-bare-repository 2>/dev/null)" = true ] || { echo "REFUSE(1): $STORE is not the bare SCRIP store"; exit 1; }
[ -d "$GH/skills" ] || { echo "REFUSE(1): no skills at $GH/skills"; exit 1; }
[ -f "$FROM/.claude/settings.json" ] && [ -f "$FROM/.claude/settings.local.json" ] || { echo "REFUSE(1): $FROM/.claude has no settings to template"; exit 1; }
src_seat="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["env"]["S4E_SEAT"])' "$FROM/.claude/settings.local.json")"
# THE CLONE BORROWS THE STORE'S OBJECTS (clone --shared writes the alternates line), origin is github, and main stands at origin's newest head.
git clone -q --shared --no-checkout "$STORE" "$root/SCRIP" && git -C "$root/SCRIP" remote set-url origin "$(git --git-dir="$STORE" remote get-url origin)" || exit 1
git -C "$root/SCRIP" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' && git -C "$root/SCRIP" fetch -q origin && git -C "$root/SCRIP" checkout -q -B main origin/main && git -C "$root/SCRIP" branch -q --set-upstream-to=origin/main main || exit 1
mkdir -p "$root/.claude" "/tmp/s4e/$seat" "$PO/$seat/inbox" "$PO/$seat/archive"
[ -d "$PO/$seat/HQ" ] && rmdir "$PO/$seat/HQ"; echo cio > "$PO/$seat/HQ"
sed "s#$FROM#$root#g; s#\b$src_seat\b#$seat#g" "$FROM/.claude/settings.json" > "$root/.claude/settings.json"
sed "s#$FROM#$root#g; s#\b$src_seat\b#$seat#g" "$FROM/.claude/settings.local.json" > "$root/.claude/settings.local.json"
python3 -c 'import json,sys; [json.load(open(f)) for f in sys.argv[1:]]' "$root/.claude/settings.json" "$root/.claude/settings.local.json" || exit 1
[ -f "$FROM/.claude/banner_compact.py" ] && cp "$FROM/.claude/banner_compact.py" "$root/.claude/"
# THE SKILLS ARE BORN WITH THE ROOT (Lon 2026-11-08 07:3x through officer_01: "Tell CIO his failure and get him to fix ALL."; the nine roots of 11-07 15:51 had no .claude/skills and
# every skill load there failed): every skill of the source root's committed .github/skills is copied in (never a symlink); propagate_skills.sh keeps them current after each landing.
# ONE COPY OF THE SKILLS (row harness-the-skills-live-once-in-the-users-claude-skills; the grader's proposal 2026-11-13 20:3x CST): once the user-level copy is installed
# (its manifest exists, propagate_skills.sh --user) every session reads it, so a new root gets no copy of its own, which nothing would keep current (senior_09 to 12 went
# stale that way); the root is refused instead if the user-level copy lacks a skill of the source. With no manifest the root copy is made as before.
_uskills="${S4E_SKILLS_USER:-$HOME/.claude/skills}"; _uman="${S4E_SKILLS_MANIFEST:-$(dirname "$_uskills")/s4e-skills.manifest}"
if [ -f "$_uman" ]; then
    for s in "$GH/skills"/*/; do n="$(basename "$s")"; [ -f "$_uskills/$n/SKILL.md" ] || { echo "REFUSE(1): the user-level skills $_uskills lack $n (run propagate_skills.sh --user); no root copy is made once $_uman exists"; exit 1; }; done
    echo "SKILLS user-level: $_uskills serves $(wc -l < "$_uman") skills; no root copy"
else
mkdir -p "$root/.claude/skills" && for s in "$GH/skills"/*/; do n="$(basename "$s")"; rm -rf "$root/.claude/skills/$n"; cp -r "$s" "$root/.claude/skills/$n"; done
[ "$(ls -d "$root/.claude/skills"/*/ 2>/dev/null | wc -l)" -ge 1 ] || { echo "REFUSE(1): no skill was installed into $root/.claude/skills (source $GH/skills)"; exit 1; }
fi
python3 "$HERE/propagate_seat_digests_cto_484.py" --apply "--root=$seat" | tail -1
echo "POPULATED $seat at $root: $(du -sh "$root" | cut -f1) (its SCRIP clone alone; S4E_SEAT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["env"]["S4E_SEAT"])' "$root/.claude/settings.local.json"))"
echo "NEXT, BY HAND: add $seat to ROSTER and FLEET: IDLE EXCEPT on MODE; reown the retired HQ's open rows to $seat; (cd $root/SCRIP && make -j4) under a run slot"
