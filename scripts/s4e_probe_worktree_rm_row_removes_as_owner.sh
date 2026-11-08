#!/usr/bin/env bash
# s4e_probe_worktree_rm_row_removes_as_owner.sh -- THE PROBE of row fleet-done-removes-the-worktree-as-its-owner-and-keeps-one-with-a-live-process (senior_06, from
# officer_05's design of 17:16 CST). MEASURED: s4e_worktree_rm_row (s4e_msg.sh), run by done and park, calls s4e_worktree.sh rm as the seat that runs the verb, which
# looks under /tmp/s4e/<that seat>/, so a worktree another seat made is never found (the u6 baton holds seven "rc=1" lines). On a scratch postoffice with one baton
# naming two marker worktrees of a seat that is not the caller: the function as written in s4e_msg.sh must remove the one nobody works in and keep the one with a
# process whose cwd is inside it, writing "kept: a live process is inside" to the baton. One line:
# WT_RM_OWNER removed_as_owner=0|1 kept_live=0|1 ledger_line=0|1 ok=0|1. rc 0 ok, 1 red, 2 could not measure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
MSG="$S4E/harness/scripts/s4e_msg.sh"
[ -f "$MSG" ] && [ -f "$S4E/harness/scripts/s4e_worktree.sh" ] || { echo "REFUSE(2): no s4e_msg.sh or s4e_worktree.sh under $S4E/harness/scripts"; exit 2; }
fn="$(sed -n '/^s4e_worktree_rm_row()/,/^    return 0; }/p' "$MSG")"
[ -n "$fn" ] || { echo "REFUSE(2): s4e_worktree_rm_row not found in $MSG"; exit 2; }
p="$(mktemp -d "/tmp/s4e/$ME/wt_own.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
own="probeown$$"; top="/tmp/s4e/$own"; row="probe-own-row-$$"; pid=""
trap '[ -n "$pid" ] && kill "$pid" 2>/dev/null; rm -rf "$p" "$top"' EXIT
mkdir -p "$p/tasks" "$top/wt-idle" "$top/wt-busy"
for n in idle busy; do printf 'name=%s\nseat=%s\n' "$n" "$own" > "$top/wt-$n/.s4e-worktree"; done
printf '# TASK %s\nGOAL: plant\nDONE-WHEN: false\nWORKTREE: %s\nWORKTREE: %s\n## NEXT\nplant\n## QA\n## LEDGER\n' "$row" "$top/wt-idle" "$top/wt-busy" > "$p/tasks/$row.task.md"
( cd "$top/wt-busy" && exec setsid sleep 120 ) < /dev/null > /dev/null 2>&1 &
pid=$!
sleep 1
( PO="$p"; ME="$ME"; eval "$fn"; s4e_worktree_rm_row "$row" ) < /dev/null > /dev/null 2>&1
ro=0; [ ! -e "$top/wt-idle" ] && ro=1
kl=0; [ -d "$top/wt-busy" ] && kl=1
ll=0; grep -q 'kept.*a live process is inside' "$p/tasks/$row.task.md" && ll=1
ok=0; [ "$ro$kl$ll" = 111 ] && ok=1
echo "WT_RM_OWNER removed_as_owner=$ro kept_live=$kl ledger_line=$ll ok=$ok"
[ "$ok" = 1 ]
