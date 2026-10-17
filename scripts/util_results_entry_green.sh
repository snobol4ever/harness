#!/usr/bin/env bash
# util_results_entry_green.sh -- ONE TEST'S VERDICT, READ FROM THE PROGRESS DATABASE THE coo WRITES (ceo CEO-1812; Lon 2026-10-17, in-chat to
# the ceo, verbatim: "have each seat fix the one bug, then tell COO to re-run that one test on the side of the cycle."). The DONE-WHEN of a
# one-bug row: the seat cures, files `s4e_test_request.sh <suite> <program>`, the coo's loop grades that one test ahead of its round robin and
# writes its two rows, and this reader closes the row from them. It runs nothing and builds nothing: the seat's own run count stays zero.
#
#   util_results_entry_green.sh <suite> <program> <red-commit>
#
# <suite> and <program> as results.tsv spells them (columns 6 and 8); <red-commit> the SCRIP tree the row's red was read on.
# EXIT 0 GREEN: the newest m3 row and the newest m4 row both read PASS, each on a clean SCRIP tree that contains <red-commit>.
# EXIT 1 RED: a mode's newest row is not PASS, or it was read on a tree older than <red-commit> or a dirty one (the cure is not graded yet).
# EXIT 2 REFUSED: bad arguments, no database, no row for a mode, or a commit this checkout does not know (pull, then re-run).
set -u
[ $# -eq 3 ] || { echo "usage: util_results_entry_green.sh <suite> <program> <red-commit>" >&2; exit 2; }
suite="$1"; prog="$2"; red="$3"
db="${S4E_PROGRESS_DB:-/home/resources/progress/results.tsv}"
repo="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
[ -r "$db" ] || { echo "REFUSE: no progress database at $db" >&2; exit 2; }
git -C "$repo" cat-file -e "$red^{commit}" 2>/dev/null || { echo "REFUSE: $red is not a commit this SCRIP knows (pull)" >&2; exit 2; }
rc=0
for m in m3 m4; do
    row="$(awk -F'\t' -v s="$suite" -v p="$prog" -v m="$m" '$6==s && $8==p && $9==m { if ($1 >= t) { t = $1; r = $1 "\t" $2 "\t" $10 } } END { print r }' "$db")"
    [ -n "$row" ] || { echo "REFUSE: no $m row for $suite $prog in $db" >&2; exit 2; }
    IFS=$'\t' read -r ts tree outcome <<< "$row"
    case "$tree" in
        *-dirty) echo "RED: $suite $prog $m read $outcome at $ts on a dirty tree $tree"; rc=1; continue;;
    esac
    git -C "$repo" cat-file -e "$tree^{commit}" 2>/dev/null || { echo "REFUSE: $tree (the $m reading's tree) is not a commit this SCRIP knows (pull)" >&2; exit 2; }
    if ! git -C "$repo" merge-base --is-ancestor "$red" "$tree"; then
        echo "RED: $suite $prog $m newest reading $outcome at $ts on $tree, which predates the red tree $red"; rc=1
    elif [ "$outcome" != PASS ]; then
        echo "RED: $suite $prog $m reads $outcome at $ts on $tree"; rc=1
    else
        echo "GREEN: $suite $prog $m reads PASS at $ts on $tree"
    fi
done
exit $rc
