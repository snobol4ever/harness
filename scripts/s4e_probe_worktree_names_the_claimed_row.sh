#!/usr/bin/env bash
# s4e_probe_worktree_names_the_claimed_row.sh -- THE PROBE of row fleet-a-worktree-made-without-row-is-named-in-the-baton-of-the-seats-one-claim
# (officer_05, 2026-11-08 13:3x CST, on the coo's telegram of 12:39: WT_MAX 32 of 32 full of LANDED or stopped work, junior_06 wt-pools, junior_10
# wt-u7a and wt-swi-modes, junior_04 wt-holder among them, while /tmp held 39 G free). MEASURED: none of those four is named by a WORKTREE: line in any
# baton, because the workers ran s4e_worktree.sh new without --row, so done and park (s4e_worktree_rm_row, fleet-queue step 6) had nothing to remove.
# On a scratch postoffice (S4E_POSTOFFICE) with one claim naming the seat and its baton:
#   s4e_worktree.sh new <name> (no --row) -> the baton gains "WORKTREE: <path>" (named=1); s4e_worktree.sh rm <name> removes it again (stripped=1).
#   The control: with a second live claim, new names no baton (ambiguous=1: two claims, no guess).
# One line: WT_ROW named=0|1 stripped=0|1 ambiguous=0|1 ok=0|1. rc 0 ok, 1 red, 2 could not measure.
# The lander copies this file to harness/scripts/s4e_probe_worktree_names_the_claimed_row.sh unchanged and lands it with the cure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
WT="$S4E/harness/scripts/s4e_worktree.sh"
[ -f "$WT" ] || { echo "REFUSE(2): no $WT"; exit 2; }
p="$(mktemp -d "/tmp/s4e/$ME/wt_row.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
n1="probe-row-a-$$"; n2="probe-row-b-$$"; t1="wt-row-plant-a-$$"; t2="wt-row-plant-b-$$"
trap 'S4E_POSTOFFICE="$p" S4E_SEAT="$ME" bash "$WT" rm "$n1" >/dev/null 2>&1; S4E_POSTOFFICE="$p" S4E_SEAT="$ME" bash "$WT" rm "$n2" >/dev/null 2>&1; rm -rf "$p"' EXIT
mkdir -p "$p/tasks" "$p/claims"
for t in "$t1" "$t2"; do printf '# TASK %s\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nplant\n## QA\n## LEDGER\n' "$t" > "$p/tasks/$t.task.md"; done
printf '%s\nRESERVED job=1 tube=tier-haiku 2026-11-08T00:00:00Z\n' "$ME" > "$p/claims/$t1.claim"
wt() { env S4E_POSTOFFICE="$p" S4E_SEAT="$ME" timeout -k 5 600 bash "$WT" "$@" < /dev/null 2>&1; }
o="$(wt new "$n1")"; rc=$?
[ "$rc" = 0 ] || { echo "REFUSE(2): new $n1 refused rc $rc: $(printf '%s' "$o" | tail -2 | tr '\n' '|' | cut -c1-200)"; exit 2; }
path="/tmp/s4e/$ME/wt-$n1"
named=0; grep -qxF "WORKTREE: $path" "$p/tasks/$t1.task.md" && named=1
wt rm "$n1" > /dev/null; stripped=0; [ "$named" = 1 ] && ! grep -qxF "WORKTREE: $path" "$p/tasks/$t1.task.md" && [ ! -e "$path" ] && stripped=1
printf '%s\nRESERVED job=2 tube=tier-haiku 2026-11-08T00:00:00Z\n' "$ME" > "$p/claims/$t2.claim"
o="$(wt new "$n2")"; rc=$?
[ "$rc" = 0 ] || { echo "REFUSE(2): new $n2 refused rc $rc"; exit 2; }
amb=0; ! grep -q "^WORKTREE: " "$p/tasks/$t1.task.md" && ! grep -q "^WORKTREE: " "$p/tasks/$t2.task.md" && amb=1
wt rm "$n2" > /dev/null
ok=0; [ "$named" = 1 ] && [ "$stripped" = 1 ] && [ "$amb" = 1 ] && ok=1
echo "WT_ROW named=$named stripped=$stripped ambiguous=$amb ok=$ok"
[ "$ok" = 1 ]
