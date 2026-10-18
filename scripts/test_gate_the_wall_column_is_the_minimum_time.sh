#!/usr/bin/env bash
# test_gate_the_wall_column_is_the_minimum_time.sh -- THE WALL COLUMN IS THE MINIMUM TIME TO RUN THE TEST (Lon 2026-10-18, in-chat to the coo, verbatim:
# "Not sure why the Wall column has such large numbers. That column is meant to represent the MINIMUM amount of time to run the test."). The progress
# table keeps one row per key, the LATEST reading, so a loaded run or a timeout overwrote the fast one and Wall summed those (Logtalk 2h35m, ProDemo
# 43m57s for eight programs). THE PAIR UNDER TEST: (1) util_progress_append.py keeps <db>.min, per key the smallest PASS seconds, only ever lowered,
# never raised by a slower PASS or set by a FAIL/HANG/zero; (2) util_suite_banner.py --set --secs keeps the smaller of the old and new wall while the
# denominator is unchanged and takes the new one when the total moves. Every arm runs on a scratch database and a scratch suite table; nothing live is
# read or written. rc 0 green, 1 red, 2 could not measure.
set -u
unset S4E_PROGRESS_DB S4E_SUITES_TSV S4E_SCORE_MD S4E_PROGRESS_OFF
H="$(cd "$(dirname "$0")" && pwd)"; G=the_wall_column_is_the_minimum_time; ROOT="${S4E_HOME:-$(cd "$H/../.." && pwd)}"
B="$ROOT/.github/scripts/util_suite_banner.py"
[ -r "$H/util_progress_append.py" ] && [ -r "$B" ] || { echo "REFUSE(2) [$G]: util_progress_append.py or the banner is missing -- cannot measure"; exit 2; }
T="$(mktemp -d)" || { echo "REFUSE(2) [$G]: mktemp failed"; exit 2; }; trap 'rm -rf "$T"' EXIT
fail=0; n=0
arm() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; fail=$((fail+1)); fi; }
mins() { python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import util_progress_append as u; print(" ".join("%s=%s" % (k[1], v) for k, v in sorted(u.min_secs_table(sys.argv[2]).items())))' "$H" "$T/db.tsv"; }
put() {  # put <program> <outcome> <secs>
    S4E_HOME="$ROOT" python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import util_progress_append as u
u.append_rows([{"class": "package", "suite": "t", "lang": "snobol4", "program": sys.argv[3], "mode": "m3", "outcome": sys.argv[4], "secs": sys.argv[5], "note": "", "config": "shipped"}], db=sys.argv[2])' "$H" "$T/db.tsv" "$@" > /dev/null 2>&1
}
put a PASS 12.5; put b FAIL 30; put c PASS 0
arm "1 a first PASS seeds the minimum; a FAIL and a zero-seconds PASS set none"   '[ "$(mins)" = "a=12.5" ]'
put a PASS 3.2; put b PASS 9
arm "2 a faster PASS lowers it and a first PASS of another program adds one"     '[ "$(mins)" = "a=3.2 b=9.0" ]'
put a PASS 99; put b HANG 60; put b FAIL 1
arm "3 a slower PASS, a HANG and a quick FAIL never raise or lower it"          '[ "$(mins)" = "a=3.2 b=9.0" ]'
: > "$T/db.tsv.current"; put a PASS 1.0
arm "4 the current-table mode (one row per key) lowers it as well"               '[ "$(mins)" = "a=1.0 b=9.0" ]'
# the banner: a scratch suite table with one row whose total is 18 and today_secs 5
printf 'key\tnick\ticon\tlang\tfirst_date\tfirst_pass\tfirst_total\ttoday_date\ttoday_pass\ttoday_total\ttree\tcriterion_changed\ttoday_excluded\ttoday_secs\nxx\tXX\t.\tsnobol4\t2026-10-01\t1\t18\t2026-10-01\t1\t18\taaaaaaaaa\t\t\t5\n' > "$T/SUITES.tsv"; : > "$T/SCORE.md"
secs() { awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="today_secs") c=i} NR==2{print $c}' "$T/SUITES.tsv"; }
set_row() {  # set_row <total> <secs> [stamp]
    S4E_SUITES_TSV="$T/SUITES.tsv" S4E_SCORE_MD="$T/SCORE.md" python3 "$B" --set xx 1 "$1" 2026-10-18 bbbbbbbbb --secs "$2" ${3:+--criterion-changed "$3"} > "$T/set.out" 2>&1
}
set_row 18 500
arm "5 a larger wall for the same denominator does not replace the old one"      '[ "$(secs)" = 5 ]'
set_row 18 3
arm "6 a smaller wall replaces it"                                               '[ "$(secs)" = 3 ]'
set_row 20 800 "2026-10-18:the-denominator-moved-for-the-gate"
arm "7 a moved denominator starts the wall again at the new value"               '[ "$(secs)" = 800 ]'
if [ "$fail" = 0 ]; then echo "GATE PASS [$G]: $n arms -- the ledger keeps the smallest PASS seconds and the banner keeps the smaller wall"; exit 0; fi
echo "GATE FAIL [$G]: $fail of $n arm(s) red -- Wall would again be a loaded run's clock, not the minimum time to run the test"; exit 1
