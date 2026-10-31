#!/usr/bin/env bash
# util_git_maintenance.sh [--apply] [--root=<dir>]... -- ONE CHEAP, SCHEDULED REPACK FOR EVERY SEAT ROOT'S REPOS, IN PLACE OF GIT'S AUTO-GC
# (ceo CEO-2082, 2026-10-31; Lon in-chat to the ceo, verbatim: "We have contention on resources that maybe many can be shared.").
# MEASURED 12:5x CDT at load 48 to 62: two `git gc --auto` runs, started by an ordinary fetch, had each burned 1.3 to 1.6 cores for 17 and
# 20 minutes (pack-objects --all over a 1.5 to 2.1 GB corpus, in /home/claude_ceo/corpus and /home/claude_packages/corpus). git's
# gc.autoPackLimit is 50 and the fleet's repos sat at 35 to 51 packs (cqo, cao and dotnet corpus at 50, snobol4 SCRIP at 50), so the next
# fetch in each one starts the same full repack at a random hour, nineteen roots times four repos: a hidden, recurring tax nobody scheduled.
# THE CURE has two halves. Lon sets `git config --global gc.auto 0` once, so no fetch starts a repack. This script is the replacement: a
# GEOMETRIC repack (git repack -d -l --geometric=2) rolls the small packs a fetch leaves into larger ones and leaves the big base pack alone,
# so its cost is the size of the recent packs, not the size of the corpus; loose objects are packed by the same call. It runs at nice 19
# and idle I/O, one repo at a time, in s4e-batch.slice when systemd-run can place it (ARCH-SHARED-DEVELOPMENT section 5: batch work runs
# in the batch class). Without --apply it prints each repo's pack count and size and what it would do; it never touches a work tree.
# Install (Lon): crontab line  17 3 * * *  bash /home/claude_ceo/harness/scripts/util_git_maintenance.sh --apply >> /home/resources/progress/GIT_MAINT.log 2>&1
set -u
APPLY=0; ROOTS=()
for a in "$@"; do case "$a" in --apply) APPLY=1;; --root=*) ROOTS+=("${a#--root=}");; -h|--help) sed -n '2,15p' "$0"; exit 0;; *) echo "usage: util_git_maintenance.sh [--apply] [--root=<dir>]..." >&2; exit 2;; esac; done
[ "${#ROOTS[@]}" -gt 0 ] || ROOTS=(/home/claude_*)
run() { if command -v systemd-run >/dev/null 2>&1 && systemctl --user is-active s4e-batch.slice >/dev/null 2>&1; then
          systemd-run --user --quiet --wait --collect --slice=s4e-batch.slice -p Nice=19 -p IOSchedulingClass=idle "$@"
        else nice -n 19 ionice -c3 "$@"; fi; }
n=0; done_n=0; stamp() { date '+%F %T %Z'; }
echo "GIT_MAINT $(stamp) apply=$APPLY gc.auto(global)=$(git config --global --get gc.auto || echo unset)"
for root in "${ROOTS[@]}"; do
  for repo in "$root"/SCRIP "$root"/corpus "$root"/harness "$root"/.github "$root"/snobol4dotnet "$root"/snobol4jvm; do
    [ -d "$repo/.git/objects/pack" ] || continue
    [ -f "$repo/.git/gc.pid" ] && kill -0 "$(cut -d' ' -f1 "$repo/.git/gc.pid" 2>/dev/null)" 2>/dev/null && { echo "  SKIP  $repo (a gc is running)"; continue; }
    n=$((n+1)); packs=$(ls "$repo"/.git/objects/pack/*.pack 2>/dev/null | wc -l); size=$(du -s --block-size=M "$repo/.git/objects" 2>/dev/null | cut -f1)
    if [ "$APPLY" = 1 ]; then
      t0=$(date +%s); run git -C "$repo" repack -d -l -q --geometric=2 >/dev/null 2>&1; rc=$?
      after=$(ls "$repo"/.git/objects/pack/*.pack 2>/dev/null | wc -l)
      printf '  %-4s %-40s packs %3s -> %3s  %7s  %4ss\n' "$([ $rc = 0 ] && echo ok || echo rc$rc)" "$repo" "$packs" "$after" "$size" "$(( $(date +%s) - t0 ))"
      [ $rc = 0 ] && done_n=$((done_n+1))
    else printf '  DRY  %-40s packs %3s  %7s  (would repack --geometric=2)\n' "$repo" "$packs" "$size"; fi
  done
done
echo "GIT_MAINT $(stamp) repos=$n repacked=$done_n"
