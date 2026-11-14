#!/usr/bin/env bash
# util_suite_rows_follow.sh [--dry-run] [KEY...] -- THE SUITE TABLE FOLLOWS THE STORE, ON THE CLOCK, NOT BY THE COO'S HAND (the coo 2026-11-14,
# on Lon's word in the coo's window, verbatim: "get these process automated into the shell scripts. quit depending on your feeble mind to do things.").
# MEASURED that noon: IcnTcll1 read 13/14 and TreallaTests 317/318 in SUITES.tsv while the progress store read 14/14 and 318/318 for an hour, and
# SnoRungs and SnoCases stood behind the store because util_score_row.py refuses a moved denominator without a stamp, so every suite a new witness
# joined froze until the coo stamped it by hand.
# THE RULE, for each suite key of SUITE_RUNNERS.tsv (or the KEYs named):
#   util_score_row.py from-progress --suite K --dry-run; when its pass/total differ from the table's row, write the row (util_score_row.py from-progress).
#   A refusal for a denominator that GREW is stamped from the corpus commits that changed the suite's table since yesterday:
#   --criterion-changed 'DATE:<n> entries joined by corpus <hashes>'. A denominator that SHRANK is never stamped here (Lon 2026-11-11: "Keep all the
#   test suite numbers honest"): it is named and left for a seat. Any other refusal (an unread entry, a half read) is left for the cycle and named.
# OUTPUT: FOLLOW_ROW key=K table=P/T store=P/T wrote|stamped|left:<reason>, then FOLLOW_BOARD read=N moved=N wrote=N stamped=N left=N; rc 0
# (rc 2 when it cannot read the store or the table). --dry-run writes nothing. The tick runs it; a seat may run it by hand.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_paths.sh" || { echo "REFUSE(2): lib_paths.sh"; exit 2; }
DRY=0; KEYS=()
for a in "$@"; do case "$a" in --dry-run) DRY=1;; -*) echo "REFUSE(2): unknown switch $a"; exit 2;; *) KEYS+=("$a");; esac; done
TABLE="${S4E_SUITES_TSV:-/home/resources/progress/SUITES.tsv}"; RUN="$HERE/SUITE_RUNNERS.tsv"
[ -f "$TABLE" ] && [ -f "$RUN" ] || { echo "REFUSE(2): no suite table $TABLE or runner table $RUN"; exit 2; }
[ ${#KEYS[@]} -gt 0 ] || mapfile -t KEYS < <(awk -F'\t' '!/^#/ && NF >= 5 && ($2 == "master" || $2 == "pkg") {print $1}' "$RUN")
row_of() { awk -F'\t' -v k="$1" '$1 == k && $9 ~ /^[0-9]+$/ && $10 ~ /^[0-9]+$/ {print $9 "/" $10; exit}' "$TABLE"; }
read_n=0; moved=0; wrote=0; stamped=0; left=0
for k in "${KEYS[@]}"; do
    t="$(row_of "$k")"; [ -n "$t" ] || continue
    o="$(S4E_MODES=m3 timeout -k 5 300 python3 -I "$S4E_HARNESS/scripts/util_score_row.py" from-progress --suite "$k" --dry-run 2>&1)"
    s="$(printf '%s\n' "$o" | grep -m1 "^SUITE_ROW suite=$k " | grep -oE 'pass=[0-9]+ total=[0-9]+' | sed 's/pass=//; s/ total=/\//')"
    read_n=$((read_n + 1)); [ -n "$s" ] || continue; [ "$s" = "$t" ] && continue
    moved=$((moved + 1))
    if [ "$DRY" = 1 ]; then echo "FOLLOW_ROW key=$k table=$t store=$s left:dry-run"; continue; fi
    w="$(S4E_MODES=m3 timeout -k 5 300 python3 -I "$S4E_HARNESS/scripts/util_score_row.py" from-progress --suite "$k" 2>&1)"
    now="$(row_of "$k")"
    if [ "$now" = "$s" ]; then wrote=$((wrote + 1)); echo "FOLLOW_ROW key=$k table=$t store=$s wrote"; continue; fi
    if printf '%s\n' "$w" | grep -q 'denominator moves'; then
        t0="${t#*/}"; s0="${s#*/}"
        if [ "$s0" -gt "$t0" ]; then
            dir="$(awk -F'\t' -v k="$k" '$1 == k {print $5; exit}' "$RUN")"; dir="${dir#corpus/}"
            hs="$(git -C "$S4E_CORPUS" --no-optional-locks log --since='36 hours ago' --format=%h -- "$dir" 2>/dev/null | head -4 | tr '\n' ' ')"
            stamp="$(date +%F):$((s0 - t0)) entr$( [ $((s0 - t0)) = 1 ] && echo y || echo ies) joined $k by corpus ${hs:-commits of the last 36 hours} (util_suite_rows_follow.sh)"
            S4E_MODES=m3 timeout -k 5 300 python3 -I "$S4E_HARNESS/scripts/util_score_row.py" from-progress --suite "$k" --criterion-changed "$stamp" > /dev/null 2>&1
            now="$(row_of "$k")"
            if [ "$now" = "$s" ]; then stamped=$((stamped + 1)); echo "FOLLOW_ROW key=$k table=$t store=$s stamped: $stamp"; continue; fi
            left=$((left + 1)); echo "FOLLOW_ROW key=$k table=$t store=$s left:the stamped write did not take"; continue
        fi
        left=$((left + 1)); echo "FOLLOW_ROW key=$k table=$t store=$s left:the denominator SHRANK, which a seat must name"; continue
    fi
    why="$(printf '%s\n' "$w" | grep -m1 -E 'REFUSE' | cut -c1-120)"
    left=$((left + 1)); echo "FOLLOW_ROW key=$k table=$t store=$s left:${why:-the write did not take}"
done
echo "FOLLOW_BOARD read=$read_n moved=$moved wrote=$wrote stamped=$stamped left=$left$( [ "$DRY" = 1 ] && echo ' (dry run)')"
exit 0
