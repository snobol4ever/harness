#!/usr/bin/env bash
# util_finding_fold_before_delete.sh -- THE SWEEP: fold a FINDING's measured claims into its live citers, then delete.
# (RULES.md line 31; Lon 2026-09-18 "I'll just delete them periodically. We should probably do a summarization when I
# delete."; ceo CEO-859/861.  Row: finding-summarization-gate-refuses-to-delete-an-unfolded-cited-finding.)
#
# This is a THIN WRAPPER over util_finding_fold_before_delete.py and it is deliberately thin: the work is character-offset
# marker parsing and verbatim-subset matching over files that write ONE PARAGRAPH PER LINE (a GOAL cursor entry is a single
# 19 KB line), which bash's line tools cannot do without the generous window CEO-860 proved exempts live violations.
# The .sh exists because the row's DONE-WHEN names it and because every other sweep in ../harness/scripts/ is invoked as one.
#
#   util_finding_fold_before_delete.sh                      # REPORT: index every tracked FINDING and its citers
#   util_finding_fold_before_delete.sh --apply <name>        # write the fold block (claim lines copied VERBATIM)
#   util_finding_fold_before_delete.sh --delete <name>       # delete, REFUSING rc=2 on a cited-and-unfolded FINDING
#   util_finding_fold_before_delete.sh --deleted-since <rev> # grade what a landing already deleted
#   --tree/--scrip/--tasks point it at a scratch copy; that is how the gate proves it can say no.
# rc: 0 clean · 1 a deleted FINDING left a cited claim behind · 2 REFUSED (unreadable tree, zero FINDINGs indexed,
# zero files scanned, a fold that would be written empty).  A zero from a tool that read nothing is not a zero.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$HERE/util_finding_fold_before_delete.py"
[ -r "$ENGINE" ] || { echo "⛔ REFUSED-TO-GRADE(2): engine missing: $ENGINE"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE(2): python3 not on PATH"; exit 2; }
exec python3 "$ENGINE" "$@"
