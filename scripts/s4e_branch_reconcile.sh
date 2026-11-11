#!/usr/bin/env bash
# s4e_branch_reconcile.sh -- ONE BRANCH RECONCILED: WHAT IT HOLDS IS LANDED OR ITS REASON IS WRITTEN, AND THE BRANCH GOES (the cio 2026-11-11, CIO-125,
# CIO-126; Lon 2026-11-11, verbatim: "Regarding the 30 GitHub repo branches, go figure out for each what it has new and which bugs are fixed. Then
# extract all the fixes and remove the branches afterward." and "Regarding all local repo branches, do the same."). Every branch that held work main
# lacks was bundled on 2026-11-11 into /home/resources/branch-archive/2026-11-11/<repo>/<where>__<branch>.bundle (git fetch BUNDLE restores its exact
# commits) and listed in /home/resources/progress/BRANCH-STUDY-2026-11-11.tsv with its patches in the .detail.txt beside it.
# usage: s4e_branch_reconcile.sh exists WHERE REPO BRANCH      rc 0 the branch still stands (WHERE is origin or a seat name), rc 1 it is gone
#        s4e_branch_reconcile.sh check  WHERE REPO BRANCH      rc 0 the ledger holds its line, rc 1 it does not
#        s4e_branch_reconcile.sh done   WHERE REPO BRANCH VERDICT "EVIDENCE"
#            VERDICT is LANDED (the hash and the proof in EVIDENCE), OBSOLETE (main already answers as the oracle: both outputs in EVIDENCE), ARCHIVED
#            (a prototype or a patch that no longer applies: what it adds and the row it belongs to), DUPLICATE (of which branch) or ROW (the new row's
#            topic). Refuses rc 2 unless the bundle stands in the archive or the branch holds no patch main lacks, and unless EVIDENCE has 40 characters
#            or more. Writes one line to the ledger, then deletes the branch in the seat folder; a branch on origin, or one an old worktree has checked
#            out, is left for the cio's sweep and the line says so.
#        s4e_branch_reconcile.sh sweep-origin                  the cio's: deletes on origin every branch whose ledger line is written (git push --delete)
# The ledger: /home/resources/progress/BRANCH-RECONCILE-2026-11-11.tsv (time, where, repo, branch, tip, verdict, evidence, bundle).
set -u
A="${S4E_BRANCH_ARCHIVE:-/home/resources/branch-archive/2026-11-11}"; L="${S4E_BRANCH_LEDGER:-/home/resources/progress/BRANCH-RECONCILE-2026-11-11.tsv}"
ROOT="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
die() { echo "$1"; exit "${2:-2}"; }
verb="${1:-}"; where="${2:-}"; repo="${3:-}"; br="${4:-}"
tip_of() { if [ "$where" = origin ]; then git -C "$ROOT/$repo" ls-remote --heads origin "$br" 2>/dev/null | cut -c1-9; else git -C "/home/claude_$where/$repo" rev-parse --short=9 -q --verify "refs/heads/$br" 2>/dev/null; fi; }
in_ledger() { [ -f "$L" ] && awk -F'\t' -v w="$where" -v r="$repo" -v b="$br" '$2==w && $3==r && $4==b {f=1} END{exit f?0:1}' "$L"; }
case "$verb" in
  exists) [ -n "$br" ] || die "REFUSE(2): usage: exists WHERE REPO BRANCH"; [ -n "$(tip_of)" ] && exit 0 || exit 1 ;;
  check)  [ -n "$br" ] || die "REFUSE(2): usage: check WHERE REPO BRANCH"; in_ledger && { echo "RECONCILED $where $repo $br"; exit 0; } || { echo "NOT RECONCILED $where $repo $br: no line in $L"; exit 1; } ;;
  done)
    verdict="${5:-}"; ev="${6:-}"
    case "$verdict" in LANDED|OBSOLETE|ARCHIVED|DUPLICATE|ROW) ;; *) die "REFUSE(2): VERDICT is LANDED, OBSOLETE, ARCHIVED, DUPLICATE or ROW" ;; esac
    [ "${#ev}" -ge 40 ] || die "REFUSE(2): the evidence is under 40 characters; say what was measured"
    case "$ev" in *$'\t'*|*$'\n'*) die "REFUSE(2): the evidence holds a tab or a newline" ;; esac
    in_ledger && die "ALREADY RECONCILED $where $repo $br" 0
    safe="$(printf '%s' "${where}__${br}" | sed 's/[^A-Za-z0-9_.-]/_/g')"; b="$A/$repo/$safe.bundle"; tip="$(tip_of)"
    [ -n "$tip" ] || die "REFUSE(1): no branch $br in $where $repo" 1
    if [ ! -f "$b" ]; then
        if [ "$where" = origin ]; then src="$ROOT/$repo"; ref="$(git -C "$src" ls-remote --heads origin "$br" | cut -f1)"; else src="/home/claude_$where/$repo"; ref="refs/heads/$br"; fi
        n="$(GIT_ALTERNATE_OBJECT_DIRECTORIES="$src/.git/objects" git -C "$ROOT/$repo" cherry origin/main "$ref" 2>/dev/null | grep -c '^+ ')"
        [ "$n" = 0 ] || die "REFUSE(2): $where $repo $br has no bundle at $b and holds $n patch(es) main lacks: bundle it first (git bundle create $b origin/main..$br)"
        b="-"
    fi
    [ -f "$L" ] || printf '# BRANCH RECONCILE: time_cst\twhere\trepo\tbranch\ttip\tverdict\tevidence\tbundle\n' > "$L"
    note=""
    if [ "$where" = origin ]; then note=" [on origin: the cio's sweep deletes it]"
    elif ! git -C "/home/claude_$where/$repo" branch -D "$br" >/dev/null 2>&1; then note=" [not deleted: an old worktree has it checked out]"; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M')" "$where" "$repo" "$br" "$tip" "$verdict" "$ev$note" "$b" >> "$L"
    echo "RECONCILED $where $repo $br -> $verdict$note" ;;
  sweep-origin)
    [ "${S4E_SEAT:-}" = cio ] || die "REFUSE(2): sweep-origin is the cio's verb"
    n=0
    while IFS=$'\t' read -r _t w r b _rest; do
        [ "$w" = origin ] || continue
        [ -n "$(git -C "$ROOT/$r" ls-remote --heads origin "$b" 2>/dev/null)" ] || continue
        git -C "$ROOT/$r" push -q origin --delete "$b" && { n=$((n + 1)); echo "DELETED on origin: $r $b"; }
    done < <(grep -v '^#' "$L" 2>/dev/null)
    echo "SWEPT_ORIGIN deleted=$n" ;;
  *) die "REFUSE(2): usage: s4e_branch_reconcile.sh exists|check|done WHERE REPO BRANCH [VERDICT \"EVIDENCE\"] | sweep-origin" ;;
esac
