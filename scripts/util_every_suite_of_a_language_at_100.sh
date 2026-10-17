#!/usr/bin/env bash
# util_every_suite_of_a_language_at_100.sh <lang> -- the DONE-WHEN of the NONET lane rows (ceo 2026-09-25, CEO-1266; Lon, in-chat to the ceo: "widen our efforts
# to get all language test suites to 100%" and "Go now to NONET mode."): every row of .github/SUITES.tsv for <lang> -- rung suites, packages and benches -- reads
# today_pass == today_total with a reading on file. It reads the leaderboard the suites' own runners write through util_score_row.py and runs no suite itself;
# a row is only as fresh as its runner's last pass, so a lane closes this row on a pass it just made. rc 0 every suite at 100% / 1 one short / 2 no rows or file.
L="${1:-}"; [ -n "$L" ] || { echo "REFUSED(2): name a language"; exit 2; }
. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh"; T="$(suites_tsv "${S4E_HOME:-}")"; [ -r "$T" ] || { echo "REFUSED(2): $T is unreadable"; exit 2; }
awk -F'\t' -v L="$L" '$0 !~ /^#/ && $1 != "key" && $4 == L {
    n++; p = $9; t = $10; ok = (p != "" && t != "" && p + 0 == t + 0 && t + 0 > 0); if (!ok) short++
    printf "%s %-10s %s/%s  tree %s\n", (ok ? "ok " : "RED"), $2, (p == "" ? "-" : p), (t == "" ? "-" : t), $11 }
  END { if (!n) { print "REFUSED(2): no SUITES.tsv row for " L; exit 2 }
        if (short) { printf "RED: %d of %d %s suites short of 100%%\n", short, n, L; exit 1 }
        printf "GREEN: all %d %s suites at 100%%\n", n, L; exit 0 }' "$T"
