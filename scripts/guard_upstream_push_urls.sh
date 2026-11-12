#!/usr/bin/env bash
# Disable the PUSH url on every upstream clone under /home/resources (origins outside github.com/snobol4ever), the guard
# csnobol4 has carried since s1xx (pushurl DISABLED_NEVER_PUSH_TO_PHILBUDNE). Fetch/pull keep working; a push fails in git
# itself before any network, so it no longer depends on the permission classifier's judgment (GOAL-CEO CEO-287: after the
# 2026-09-05 trust-text rewrite the classifier let a push attempt reach the upstream remote; it died only on credentials).
# Lon-run: the ceo seat is refused the loop as a bulk config rewrite.
#   bash guard_upstream_push_urls.sh --dry-run    # print what would change, change nothing
#   bash guard_upstream_push_urls.sh              # apply, then print every repo's fetch and push url
# rc 0 = applied (or dry run) · rc 2 = nothing found under /home/resources
set -u
dry=0; [ "${1:-}" = "--dry-run" ] && dry=1
n=0
for d in /home/resources/*/; do
  [ -d "$d/.git" ] || continue
  u="$(git -C "$d" remote get-url origin 2>/dev/null)" || continue
  n=$((n+1))
  case "$u" in
    *github.com[:/]snobol4ever/*) printf 'keep   %-24s push -> %s\n' "$(basename "$d")" "$(git -C "$d" remote get-url --push origin)";;
    *) if [ $dry = 1 ]; then printf 'WOULD  %-24s push %s -> DISABLED_NEVER_PUSH_UPSTREAM\n' "$(basename "$d")" "$(git -C "$d" remote get-url --push origin)"
       else git -C "$d" remote set-url --push origin DISABLED_NEVER_PUSH_UPSTREAM; printf 'guard  %-24s fetch %s | push %s\n' "$(basename "$d")" "$u" "$(git -C "$d" remote get-url --push origin)"; fi;;
  esac
done
[ $n -gt 0 ] || { echo "REFUSED rc=2: no git repos with an origin under /home/resources"; exit 2; }
echo "repos seen: $n $([ $dry = 1 ] && echo '(dry run, nothing changed)')"
