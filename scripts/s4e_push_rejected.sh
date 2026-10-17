#!/usr/bin/env bash
# s4e_push_rejected.sh -- REPORT A REJECTED PUSH, ONE LINE, NO MESSAGE (ceo CEO-1711).
# Lon 2026-10-14 13:4x CDT, in-chat to the ceo, verbatim: "So maybe seats just report REJECTED pushes?"
# Run it ONCE each time a `git push` of yours is REJECTED (non-fast-forward: origin moved while you rebased, built and proved),
# from the repository whose push was refused:   bash /path/to/harness/scripts/s4e_push_rejected.sh [repo-dir]
# It appends one tab-separated line to $S4E_POSTOFFICE/PUSH_REJECTED.tsv (default /home/resources/postoffice):
#   utc-time  seat  repo  your-HEAD  origin-main-head
# The ceo's .github/scripts/util_relay_trigger.py counts these per seat per hour; a seat losing races is what starts the relay
# (CEO-1709: one seat at a time holds the push baton). Your reflog already counts your rebases; this counts the races you lost.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
repo="${1:-$PWD}"
po="${S4E_POSTOFFICE:-/home/resources/postoffice}"
[ -d "$po" ] || { echo "REFUSE(2): no postoffice at $po -- nothing recorded"; exit 2; }
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "REFUSE(2): $repo is not a git repository -- nothing recorded"; exit 2; }
seat="$(bash "$here/../harness/scripts/s4e_msg.sh" whoami 2>/dev/null | tail -1 | tr -d '[:space:]')"
[ -n "$seat" ] || seat="unknown-$(id -un)"
name="$(basename "$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)")"
mine="$(git -C "$repo" rev-parse --short=9 HEAD 2>/dev/null)"
theirs="$(timeout -k 5 20 git -C "$repo" ls-remote origin refs/heads/main 2>/dev/null | cut -c1-9)"
printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$seat" "${name:-?}" "${mine:-?}" "${theirs:-?}" >> "$po/PUSH_REJECTED.tsv" || { echo "REFUSE(2): could not append to $po/PUSH_REJECTED.tsv"; exit 2; }
echo "recorded: rejected push by $seat in ${name:-?} (HEAD ${mine:-?}, origin ${theirs:-?}) -> $po/PUSH_REJECTED.tsv"
