#!/usr/bin/env bash
# s4e_probe_worktree_new_sweeps_dead_at_the_cap.sh -- THE PROBE of row fleet-worktree-new-sweeps-dead-worktrees-once-at-the-cap (senior_06, from officer_05's design
# of 17:16 CST: 37 worktrees stood against WT_MAX=32 and every seat was refused, while seven of them were named by DONE rows with nobody inside). On a scratch TOP
# (S4E_WT_TOP) and a scratch postoffice with WT_MAX=2 and three old marker worktrees of one seat: one named by a DONE row, one by a CLAIMED row, one named by no baton.
# new must sweep the DONE one (prints SWEPT 1, removes it), leave the other two standing, recount (the refusal then says 2 worktrees, it said 3), and the sweep
# verb must remove a second planted DONE one. No real worktree is made (the cap still refuses after the sweep). One line:
# WT_SWEEP swept=0|1 dead_gone=0|1 live_and_unnamed_stand=0|1 recounted=0|1 sweep_verb=0|1 ok=0|1. rc 0 ok, 1 red, 2 could not measure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
WT="$S4E/harness/scripts/s4e_worktree.sh"
[ -f "$WT" ] || { echo "REFUSE(2): no $WT"; exit 2; }
t="$(mktemp -d "/tmp/s4e/$ME/wt_swp.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
p="$t/po"; top="$t/top"
trap 'rm -rf "$t"' EXIT
mkdir -p "$p/tasks" "$top/$ME"
for n in dead dead2 live orphan; do mkdir -p "$top/$ME/wt-$n"; printf 'name=%s\nseat=%s\n' "$n" "$ME" > "$top/$ME/wt-$n/.s4e-worktree"; touch -d '2 hours ago' "$top/$ME/wt-$n"; done
for r in dead dead2 live; do printf '# TASK r-%s\nGOAL: plant\nDONE-WHEN: false\nWORKTREE: %s\n## NEXT\nplant\n## QA\n## LEDGER\n' "$r" "$top/$ME/wt-$r" > "$p/tasks/r-$r.task.md"; done
printf '3\tr-dead\t%s\tDONE\n3\tr-live\t%s\tCLAIMED:%s\n' "$ME" "$ME" "$ME" > "$p/QUEUE.tsv"
printf '3\tr-dead2\t%s\tDONE\n' "$ME" > "$p/QUEUE.done.tsv"
rmdead2() { mv "$top/$ME/wt-dead2" "$t/dead2.parked"; }
rmdead2
wt() { env S4E_WT_TOP="$top" S4E_POSTOFFICE="$p" WT_MAX=2 S4E_SEAT="$ME" timeout -k 5 300 bash "$WT" "$@" < /dev/null 2>&1; }
o="$(wt new probe-sweep-$$)"
sw=0; printf '%s\n' "$o" | grep -q '^SWEPT 1$' && sw=1
dg=0; [ ! -e "$top/$ME/wt-dead" ] && dg=1
ls_=0; [ -d "$top/$ME/wt-live" ] && [ -d "$top/$ME/wt-orphan" ] && ls_=1
rc=0; printf '%s\n' "$o" | grep -q 'REFUSE(2): 2 worktrees' && rc=1
mv "$t/dead2.parked" "$top/$ME/wt-dead2"; touch -d '2 hours ago' "$top/$ME/wt-dead2"
o2="$(wt sweep)"
sv=0; printf '%s\n' "$o2" | grep -q '^SWEPT 1$' && [ ! -e "$top/$ME/wt-dead2" ] && sv=1
ok=0; [ "$sw$dg$ls_$rc$sv" = 11111 ] && ok=1
echo "WT_SWEEP swept=$sw dead_gone=$dg live_and_unnamed_stand=$ls_ recounted=$rc sweep_verb=$sv ok=$ok"
[ "$ok" = 1 ]
