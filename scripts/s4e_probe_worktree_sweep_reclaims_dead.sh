#!/usr/bin/env bash
# s4e_probe_worktree_sweep_reclaims_dead.sh -- THE PROBE of row fleet-worktree-sweep-reclaims-landed-escalated-and-unnamed-worktrees-and-saves-the-unlanded-patch
# (CIO-17, 2026-11-09). Four real git worktrees of this root's SCRIP on a scratch TOP (S4E_WT_TOP) and a scratch postoffice (S4E_POSTOFFICE): (a) a DONE row's,
# one commit behind origin/main with one file set to origin/main's bytes (landed, nothing lost), idle 31 minutes; (b) a row CLAIMED by another seat, with an
# unlanded tracked edit, idle 61 minutes; (c) a worktree no baton names, with an untracked file, idle 121 minutes; (d) the seat's own CLAIMED worktree, idle 5
# minutes. The sweep must print SWEPT 3 done=1 left=1 unnamed=1, remove a, b and c, keep d, write a patch for b and one for c (each holding its edit) and none
# for a, and name b's patch in r-b's LEDGER. One line per check, then WT_SWEEP_RECLAIM ok=0|1. rc 0 ok, 1 red, 2 could not measure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
WT="$S4E/harness/scripts/s4e_worktree.sh"; SC="$S4E/SCRIP"
[ -f "$WT" ] || { echo "REFUSE(2): no $WT"; exit 2; }
git -C "$SC" rev-parse -q --verify origin/main~1 >/dev/null 2>&1 || { echo "REFUSE(2): origin/main~1 is not a commit in $SC"; exit 2; }
F="$(git -C "$SC" diff --name-only origin/main~1 origin/main 2>/dev/null | head -1)"
[ -n "$F" ] && git -C "$SC" cat-file -e "origin/main:$F" 2>/dev/null || { echo "REFUSE(2): origin/main~1 and origin/main name no file origin/main holds"; exit 2; }
t="$(mktemp -d "/tmp/s4e/$ME/wt_swr.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
p="$t/po"; top="$t/top"
mkdir -p "$p/tasks" "$top/$ME"
cleanup() {
    local n
    for n in a b c d; do git -C "$SC" worktree remove --force --force "$top/$ME/wt-$n/SCRIP" >/dev/null 2>&1; done
    git -C "$SC" worktree prune >/dev/null 2>&1
    rm -rf "$t"
}
trap cleanup EXIT
mk() {
    local n="$1" base="$2" d="$top/$ME/wt-$1"
    mkdir -p "$d" && git -C "$SC" worktree add -q --detach "$d/SCRIP" "$base" || return 1
    printf 'name=%s\nseat=%s\nbase=%s\nsha=\nmade=\ncorpus=sparse:default\nrepo=SCRIP\n' "$n" "$ME" "$base" > "$d/.s4e-worktree"
}
mk a origin/main~1 || { echo "REFUSE(2): cannot make worktree a"; exit 2; }
git -C "$top/$ME/wt-a/SCRIP" show "origin/main:$F" > "$top/$ME/wt-a/SCRIP/$F" || { echo "REFUSE(2): cannot write origin/main's $F into a"; exit 2; }
mk b origin/main~1 || { echo "REFUSE(2): cannot make worktree b"; exit 2; }
printf 'probe-b-edit\n' >> "$top/$ME/wt-b/SCRIP/$F"
mk c origin/main || { echo "REFUSE(2): cannot make worktree c"; exit 2; }
printf 'probe-c-untracked\n' > "$top/$ME/wt-c/SCRIP/probe-c-untracked.txt"
mk d origin/main || { echo "REFUSE(2): cannot make worktree d"; exit 2; }
printf '# TASK r-a\nGOAL: plant\nDONE-WHEN: false\nWORKTREE: %s\n## NEXT\nplant\n## QA\n## LEDGER\n' "$top/$ME/wt-a" > "$p/tasks/r-a.task.md"
printf '# TASK r-b\nGOAL: plant\nDONE-WHEN: false\nWORKTREE: %s\n## NEXT\nplant\n## QA\n## LEDGER\n' "$top/$ME/wt-b" > "$p/tasks/r-b.task.md"
printf '# TASK r-d\nGOAL: plant\nDONE-WHEN: false\nWORKTREE: %s\n## NEXT\nplant\n## QA\n## LEDGER\n' "$top/$ME/wt-d" > "$p/tasks/r-d.task.md"
printf '3\tr-a\t%s\tDONE\n3\tr-b\tprobe_other\tCLAIMED:probe_other\n3\tr-d\t%s\tCLAIMED:%s\n' "$ME" "$ME" "$ME" > "$p/QUEUE.tsv"
touch -d '31 minutes ago' "$top/$ME/wt-a"; touch -d '61 minutes ago' "$top/$ME/wt-b"
touch -d '121 minutes ago' "$top/$ME/wt-c"; touch -d '5 minutes ago' "$top/$ME/wt-d"
o="$(env S4E_WT_TOP="$top" S4E_POSTOFFICE="$p" S4E_SEAT="$ME" timeout -k 5 300 bash "$WT" sweep < /dev/null 2>&1)"
pb="$(ls "$p/escalations/worktrees/$ME-b-"*.patch 2>/dev/null | head -1)"
pc="$(ls "$p/escalations/worktrees/$ME-c-"*.patch 2>/dev/null | head -1)"
ok=1
ck() { if [ "$2" = 1 ]; then echo "CHECK $1=1"; else echo "CHECK $1=0"; ok=0; fi; }
ck sweep_line "$(printf '%s\n' "$o" | grep -qx 'SWEPT 3 done=1 left=1 unnamed=1' && echo 1 || echo 0)"
ck removed_a_b_c "$([ ! -e "$top/$ME/wt-a" ] && [ ! -e "$top/$ME/wt-b" ] && [ ! -e "$top/$ME/wt-c" ] && echo 1 || echo 0)"
ck kept_d "$([ -d "$top/$ME/wt-d" ] && echo 1 || echo 0)"
ck patch_b_holds_edit "$([ -n "$pb" ] && grep -q 'probe-b-edit' "$pb" && echo 1 || echo 0)"
ck patch_c_holds_untracked "$([ -n "$pc" ] && grep -q 'probe-c-untracked' "$pc" && echo 1 || echo 0)"
ck patch_b_has_no_upstream_reversal "$([ -n "$pb" ] && [ "$(grep -c '^-[^-]' "$pb")" = 0 ] && echo 1 || echo 0)"
ck no_patch_for_landed_a "$(ls "$p/escalations/worktrees/$ME-a-"*.patch >/dev/null 2>&1 && echo 0 || echo 1)"
ck ledger_names_b_patch "$([ -n "$pb" ] && grep -qF "removed left; patch $pb" "$p/tasks/r-b.task.md" && echo 1 || echo 0)"
reg=1; for n in a b c; do git -C "$SC" worktree list --porcelain | grep -qF "worktree $top/$ME/wt-$n/SCRIP" && reg=0; done
ck unregistered_a_b_c "$reg"
echo "WT_SWEEP_RECLAIM ok=$ok"
[ "$ok" = 1 ]
