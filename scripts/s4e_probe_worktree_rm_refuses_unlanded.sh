#!/usr/bin/env bash
# s4e_probe_worktree_rm_refuses_unlanded.sh -- THE PROBE of row fleet-worktree-rm-refuses-a-worktree-holding-work-not-on-origin-main (senior_06, on the coo's
# guard of 17:31 CST and officer_05's amendment: s4e_worktree.sh rm force-removes a worktree with unlanded commits, tracked edits or untracked files; one
# cure, cto-525, was lost that way). One-repo marker worktrees of the harness repo at origin/main under /tmp/s4e/<seat>/: rm must remove a clean one and
# refuse (rc 1, the directory still there) one with a tracked edit, one with a commit, one with an untracked file; the owner's rm --discard removes an
# edited one; --discard by a seat that is not the marker's seat refuses. One line:
# WT_UNLANDED clean_removed=0|1 edit_kept=0|1 commit_kept=0|1 untracked_kept=0|1 discard_owner_removed=0|1 discard_nonowner_kept=0|1 ok=0|1. rc 0 ok, 1 red, 2 could not measure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
WT="$S4E/harness/scripts/s4e_worktree.sh"
[ -f "$WT" ] || { echo "REFUSE(2): no $WT"; exit 2; }
git -C "$S4E/harness" rev-parse -q --verify origin/main > /dev/null || { echo "REFUSE(2): no origin/main in $S4E/harness"; exit 2; }
p="$(mktemp -d "/tmp/s4e/$ME/wt_unl.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
sfx="$$"; names="probe-unl-clean-$sfx probe-unl-edit-$sfx probe-unl-commit-$sfx probe-unl-untracked-$sfx probe-unl-disc-$sfx probe-unl-nonowner-$sfx"
set -- $names; nc="$1"; ne="$2"; nm="$3"; nu="$4"; nd="$5"; nn="$6"
mk() { local wt="/tmp/s4e/$ME/wt-$1"; mkdir -p "$wt" && git -C "$S4E/harness" worktree add -q --detach "$wt/harness" origin/main && printf 'name=%s\nseat=%s\nrepo=harness\n' "$1" "${2:-$ME}" > "$wt/.s4e-worktree"; }
gone() { local wt="/tmp/s4e/$ME/wt-$1"; git -C "$S4E/harness" worktree remove --force --force "$wt/harness" > /dev/null 2>&1; rm -rf "$wt"; git -C "$S4E/harness" worktree prune > /dev/null 2>&1; }
trap 'for n in $names; do gone "$n"; done; rm -rf "$p"' EXIT
for n in "$nc" "$ne" "$nm" "$nu" "$nd"; do mk "$n" || { echo "REFUSE(2): could not make the marker worktree $n"; exit 2; }; done
mk "$nn" "probe-other-seat" || { echo "REFUSE(2): could not make the marker worktree $nn"; exit 2; }
f="$(git -C "/tmp/s4e/$ME/wt-$ne/harness" ls-files | head -1)"
[ -n "$f" ] || { echo "REFUSE(2): no tracked file in the harness worktree"; exit 2; }
for n in "$ne" "$nd" "$nn"; do printf 'probe edit\n' >> "/tmp/s4e/$ME/wt-$n/harness/$f"; done
printf 'probe commit\n' >> "/tmp/s4e/$ME/wt-$nm/harness/$f"
git -C "/tmp/s4e/$ME/wt-$nm/harness" -c user.name=probe -c user.email=probe@localhost commit -q -a -m "probe: an unlanded commit" || { echo "REFUSE(2): could not commit in the probe worktree"; exit 2; }
printf 'probe untracked\n' > "/tmp/s4e/$ME/wt-$nu/harness/probe-untracked-$sfx.txt"
rmw() { env S4E_POSTOFFICE="$p" S4E_SEAT="$ME" timeout -k 5 300 bash "$WT" rm "$@" < /dev/null > /dev/null 2>&1; }
rmw "$nc"; rcc=$?; rmw "$ne"; rce=$?; rmw "$nm"; rcm=$?; rmw "$nu"; rcu=$?; rmw "$nd" --discard; rcd=$?; rmw "$nn" --discard; rcn=$?
cr=0; [ "$rcc" = 0 ] && [ ! -e "/tmp/s4e/$ME/wt-$nc" ] && cr=1
ek=0; [ "$rce" = 1 ] && [ -d "/tmp/s4e/$ME/wt-$ne/harness" ] && ek=1
mk2=0; [ "$rcm" = 1 ] && [ -d "/tmp/s4e/$ME/wt-$nm/harness" ] && mk2=1
uk=0; [ "$rcu" = 1 ] && [ -d "/tmp/s4e/$ME/wt-$nu/harness" ] && uk=1
dr=0; [ "$rcd" = 0 ] && [ ! -e "/tmp/s4e/$ME/wt-$nd" ] && dr=1
nk=0; [ "$rcn" = 1 ] && [ -d "/tmp/s4e/$ME/wt-$nn/harness" ] && nk=1
ok=0; [ "$cr$ek$mk2$uk$dr$nk" = 111111 ] && ok=1
echo "WT_UNLANDED clean_removed=$cr edit_kept=$ek commit_kept=$mk2 untracked_kept=$uk discard_owner_removed=$dr discard_nonowner_kept=$nk ok=$ok"
[ "$ok" = 1 ]
