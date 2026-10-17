#!/usr/bin/env bash
# util_suite_row_at_or_after.sh <suite-key> <tree> -- THE SUITE TABLE ROW A DONE-WHEN READS INSTEAD OF RUNNING A BOARD
# (ceo CEO-1342 clause 5, the coo's row bus-done-runs-no-board-for-any-seat-...). Under ONE TESTING OFFICER the coo alone runs a
# board and writes its row; a landing that needs a suite's verdict asks whether the coo's row for that suite was measured on a tree
# AT OR AFTER the landing (git merge-base --is-ancestor <tree> <row's tree> in SCRIP/), and prints the row.
#   rc 0  the row's tree is at or after <tree>: the row is this landing's reading (printed: key pass/total date tree)
#   rc 1  the row's tree is BEFORE <tree>: the loop has not yet measured this landing -- wait for its next pass, never run the board
#   rc 2  could not measure: unknown key, unreadable table, a tree git cannot resolve
# The table is $S4E_HOME/.github/SUITES.tsv (key = column 1, tree = the `tree` column by header name); SCRIP is $S4E_HOME/SCRIP.
set -u
key="${1:-}"; tree="${2:-}"
[ -n "$key" ] && [ -n "$tree" ] || { echo "REFUSE(rc=2): usage: util_suite_row_at_or_after.sh <suite-key> <tree>  (keys: column 1 of SUITES.tsv, e.g. sno-rungs icn-rungs arizona gimpel)"; exit 2; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
. "$HERE/lib_suites_tsv.sh"; T="$(suites_tsv "$S4E")"; R="$S4E/SCRIP"
[ -f "$T" ] || { echo "REFUSE(rc=2): no suite table at $T"; exit 2; }
git -C "$R" rev-parse --verify -q "$tree^{commit}" >/dev/null 2>&1 || { echo "REFUSE(rc=2): $tree is not a commit in $R (fetch origin, or name the landing's hash)"; exit 2; }
row="$(awk -F'\t' -v k="$key" 'NR==2 {for (i=1;i<=NF;i++) c[$i]=i} NR>2 && $1==k {print $1 "\t" $(c["today_pass"]) "\t" $(c["today_total"]) "\t" $(c["today_date"]) "\t" $(c["tree"])}' "$T")"
[ -n "$row" ] || { echo "REFUSE(rc=2): no row keyed $key in $T -- the keys are its column 1"; exit 2; }
rtree="$(printf '%s' "$row" | cut -f5)"
[ -n "$rtree" ] || { echo "REFUSE(rc=2): the $key row carries no tree -- it has never been measured"; exit 2; }
git -C "$R" rev-parse --verify -q "$rtree^{commit}" >/dev/null 2>&1 || { echo "REFUSE(rc=2): the $key row's tree $rtree is not a commit in $R (a -dirty stamp, or an unfetched tree)"; exit 2; }
if git -C "$R" merge-base --is-ancestor "$tree" "$rtree" 2>/dev/null; then
  printf 'SUITE_ROW %s %s/%s measured %s on %s -- AT OR AFTER %s: this is the landing'"'"'s reading (the coo'"'"'s loop, CEO-1342)\n' "$(printf '%s' "$row" | cut -f1)" "$(printf '%s' "$row" | cut -f2)" "$(printf '%s' "$row" | cut -f3)" "$(printf '%s' "$row" | cut -f4)" "$rtree" "$tree"
  exit 0
fi
printf 'SUITE_ROW %s %s/%s measured %s on %s -- BEFORE %s: the loop has not measured this landing yet; wait for its next pass (never run the board: CEO-1342 clause 5)\n' "$(printf '%s' "$row" | cut -f1)" "$(printf '%s' "$row" | cut -f2)" "$(printf '%s' "$row" | cut -f3)" "$(printf '%s' "$row" | cut -f4)" "$rtree" "$tree"
exit 1
