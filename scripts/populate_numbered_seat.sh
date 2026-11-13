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
# point_at_coo ROOT REPO: the alternates line for one repo, written once (idempotent), as util_sync_root.sh writes it (the cio 2026-11-07): the seat's fetches move refs and the few new objects, never a pack.
point_at_coo() {
    local objs="/home/claude_coo/$2/.git/objects" alt="$1/$2/.git/objects/info/alternates"
    [ "$1" = /home/claude_coo ] && return 0
    [ -d "$objs" ] || return 0
    mkdir -p "$(dirname "$alt")" || return 1
    grep -qxF "$objs" "$alt" 2>/dev/null || printf '%s\n' "$objs" >> "$alt"
}
NN="${1:-}"; FROM=/home/claude_cio; [ "${2:-}" = --from ] && FROM="${3:?--from ROOT}"
# grader: the grade workers own root, which nothing but the controller syncs and builds (the coo 2026-11-07 16:23: a cio landing rebuilt the binary under job 1221)
case "$NN" in [0-9][0-9]) seat="junior_$NN";; junior_[0-9][0-9]|officer_[0-9][0-9]|senior_[0-9][0-9]|grader) seat="$NN";; *) echo "usage: populate_numbered_seat.sh NN|officer_NN|senior_NN [--from ROOT]  (NN two digits: the seat is worker_NN; a named numbered seat is itself; Lon 2026-11-07 15:4x: the Opus designers and Sonnet seniors)"; exit 2;; esac
root="/home/claude_$seat"; PO=/home/resources/postoffice
[ -d "$root" ] || { echo "REFUSE(1): $root does not exist -- Lon creates the folder (/home is root's)"; exit 1; }
[ -z "$(ls -A "$root")" ] || { echo "REFUSE(1): $root is not empty -- this script fills an empty folder only"; exit 1; }
for r in SCRIP corpus harness .github; do [ -d "$FROM/$r/.git" ] || { echo "REFUSE(1): $FROM/$r is not a repo"; exit 1; }; done
[ -f "$FROM/.claude/settings.json" ] && [ -f "$FROM/.claude/settings.local.json" ] || { echo "REFUSE(1): $FROM/.claude has no settings to template"; exit 1; }
src_seat="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["env"]["S4E_SEAT"])' "$FROM/.claude/settings.local.json")"
# THE SHARED FORM (the cio 2026-11-12, row fleet-32-16-8-4-shared-repos; /home read 67G free): each repo is cloned --shared from the coo root, so its
# objects are borrowed and none copied, and once checked out every clean file of corpus, harness and .github becomes a hard link to the read-only
# pristine (util_relink_root.py, util_shared_pristine.sh); the root keeps its own directories, so every relative path works unchanged.
COO=/home/claude_coo
for r in SCRIP corpus harness .github; do git clone -q --shared "$COO/$r" "$root/$r" && git -C "$root/$r" remote set-url origin "$(git -C "$COO/$r" remote get-url origin)" || exit 1; done
for r in SCRIP corpus harness .github; do point_at_coo "$root" "$r" || exit 1; done
for r in SCRIP corpus harness .github; do git -C "$root/$r" fetch -q origin && git -C "$root/$r" merge -q --ff-only origin/main || exit 1; done
[ -d "${S4E_SHARED:-/home/resources/shared}/corpus/.git" ] && { bash "$root/harness/scripts/util_shared_pristine.sh" update > /dev/null; python3 -I "$root/harness/scripts/util_relink_root.py" "$root" | sed 's/^/  /'; }
mkdir -p "$root/.claude" "$root/.scratch" "/tmp/s4e/$seat" "$PO/$seat/inbox" "$PO/$seat/archive"
[ -d "$PO/$seat/HQ" ] && rmdir "$PO/$seat/HQ"; echo cio > "$PO/$seat/HQ"
sed "s#$FROM#$root#g; s#\b$src_seat\b#$seat#g" "$FROM/.claude/settings.json" > "$root/.claude/settings.json"
sed "s#$FROM#$root#g; s#\b$src_seat\b#$seat#g" "$FROM/.claude/settings.local.json" > "$root/.claude/settings.local.json"
python3 -c 'import json,sys; [json.load(open(f)) for f in sys.argv[1:]]' "$root/.claude/settings.json" "$root/.claude/settings.local.json" || exit 1
[ -f "$FROM/.claude/banner_compact.py" ] && cp "$FROM/.claude/banner_compact.py" "$root/.claude/"
# THE SKILLS ARE BORN WITH THE ROOT (Lon 2026-11-08 07:3x through officer_01: "Tell CIO his failure and get him to fix ALL."; the nine roots of 11-07 15:51 had no .claude/skills and
# every skill load there failed): every skill of the source root's committed .github/skills is copied in (never a symlink); propagate_skills.sh keeps them current after each landing.
mkdir -p "$root/.claude/skills" && for s in "$FROM/.github/skills"/*/; do n="$(basename "$s")"; rm -rf "$root/.claude/skills/$n"; cp -r "$s" "$root/.claude/skills/$n"; done
[ "$(ls -d "$root/.claude/skills"/*/ 2>/dev/null | wc -l)" -ge 1 ] || { echo "REFUSE(1): no skill was installed into $root/.claude/skills (source $FROM/.github/skills)"; exit 1; }
python3 "$root/harness/scripts/propagate_seat_digests_cto_484.py" --apply "--root=$seat" | tail -1
echo "POPULATED $seat at $root: $(du -sh "$root" | cut -f1) (full corpus; S4E_SEAT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["env"]["S4E_SEAT"])' "$root/.claude/settings.local.json"))"
echo "NEXT, BY HAND: add $seat to ROSTER and FLEET: IDLE EXCEPT on MODE; reown the retired HQ's open rows to $seat; (cd $root/SCRIP && make -j4) under a run slot"
