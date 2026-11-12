#!/usr/bin/env bash
# test_gate_banner_run_column_shows_the_readings_date_and_time_range.sh -- the suite banner shows, for each row, the date and time range of the
# readings the row was assembled from, and its delta column is the last (the coo 2026-11-11, on Lon's word in the coo's window, verbatim: "The stop
# turn banner should display the date/time-range of the run that created the row." / "In the stop turn banner the delta column should be last.").
# A scratch suite table and a scratch SCORE.md; no live file is read or written.
#
# THE ARMS:
#   1  --set-run KEY FIRST LAST writes the two UTC stamps and nothing else; the same call again writes nothing
#   2  the Run cell of one day reads MM-DD HH:MM-HH:MM in the box's clock; of more than one day MM-DD>MM-DD HH:MM; with no stamps it is blank
#   3  the double-sided banner's header is Lang Suite Pass/Tot Excl M3 M4 Pct Min Run Δ on both sides, Δ last, and the row carries its Run
#   4  --set-run none none blanks the cell; a malformed stamp refuses rc 2 and leaves the row as it stood
#   5  the footer counts the suites at 100 percent as before (the State cell is found by its name, not its place)
# EXIT: 0 all arms pass, 1 an arm failed, 2 REFUSED (no banner script, no scratch directory).
set -u
H="$(cd "$(dirname "$0")" && pwd)"; NAME=banner_run_column_shows_the_readings_date_and_time_range; ROOT="${S4E_HOME:-$(cd "$H/../.." && pwd)}"
B="$H/util_suite_banner.py"
[ -f "$B" ] || { echo "REFUSE(2) [$NAME]: no $B"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_banner_run.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
printf 'key\tnick\temoji\tlang\tfirst_date\tfirst_pass\tfirst_total\ttoday_date\ttoday_pass\ttoday_total\ttree\tcriterion_changed\ttoday_excluded\ttoday_secs\nxx\tXxSuite\tx\ticon\t2026-11-01\t1\t2\t2026-11-11\t1\t2\tabc1234\t\t0\t41\nyy\tYySuite\ty\ticon\t2026-11-01\t2\t2\t2026-11-11\t2\t2\tabc1234\t\t0\t5\n' > "$T/SUITES.tsv"
: > "$T/SCORE.md"
run() { TZ=America/Chicago S4E_SUITES_TSV="$T/SUITES.tsv" S4E_SCORE_MD="$T/SCORE.md" python3 "$B" "$@" 2>&1; }
cell() { awk -F'\t' -v k="$1" -v c="$2" 'NR==1{for(i=1;i<=NF;i++) if($i==c) n=i} $1==k{print $n}' "$T/SUITES.tsv"; }
pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }
o1="$(run --set-run xx 2026-11-11T14:27:10 2026-11-11T14:31:55)"; o1b="$(run --set-run xx 2026-11-11T14:27:10 2026-11-11T14:31:55)"
[ "$(cell xx today_run_first)" = 2026-11-11T14:27:10 ] && [ "$(cell xx today_run_last)" = 2026-11-11T14:31:55 ] && [ "$(cell xx today_pass)" = 1 ] && [ "$(cell xx today_secs)" = 41 ] && [ -z "$(cell yy today_run_first)" ] \
  && printf '%s' "$o1b" | grep -q "nothing written" && ck ok "(1) --set-run writes the two stamps and no other cell; the same call again writes nothing" || ck no "(1) [$o1] [$o1b] first=[$(cell xx today_run_first)]"
g="$(run)"
printf '%s\n' "$g" | grep -q "XxSuite .* 11-11 08:27-08:31 " && ck ok "(2a) one day reads 11-11 08:27-08:31 in the box's clock" || ck no "(2a) the row: $(printf '%s\n' "$g" | grep XxSuite | cut -c1-120)"
run --set-run xx 2026-11-08T22:26:00 2026-11-11T15:12:00 > /dev/null; g2="$(run)"
printf '%s\n' "$g2" | grep -q "XxSuite .* 11-08>11-11 09:12 " && ! printf '%s\n' "$g2" | grep "YySuite" | sed 's/.*│//' | grep -qE "[0-9]{2}-[0-9]{2}[ >]" && ck ok "(2b) more than one day reads 11-08>11-11 09:12; a row with no stamps has a blank Run" || ck no "(2b) rows: $(printf '%s\n' "$g2" | grep -E 'XxSuite|YySuite' | cut -c1-170)"
printf '%s\n' "$g2" | head -1 | grep -qE '^Lang +Suite +Pass/Tot +Excl +M3 +M4 +Pct +Min +Run +Δ +│ +Lang +Suite +Pass/Tot +Excl +M3 +M4 +Pct +Min +Run +Δ *$' && ck ok "(3) the header is Lang Suite Pass/Tot Excl M3 M4 Pct Min Run Δ on both sides, Δ last" || ck no "(3) header: $(printf '%s\n' "$g2" | head -1)"
run --set-run xx none none > /dev/null; e1="$(cell xx today_run_first)$(cell xx today_run_last)"; run --set-run xx 2026-11-11T14:27:10 2026-11-11T14:31:55 > /dev/null
o4="$(run --set-run xx yesterday noon)"; r4=$?
[ -z "$e1" ] && [ "$r4" = 2 ] && [ "$(cell xx today_run_first)" = 2026-11-11T14:27:10 ] && printf '%s' "$o4" | grep -q "REFUSE(rc=2)" && ck ok "(4) none none blanks the cell; a malformed stamp refuses rc 2 and leaves the row" || ck no "(4) blank=[$e1] rc=$r4 [$o4]"
printf '%s\n' "$g2" | tail -1 | grep -q '^2 suites, 1 at 100%' && ck ok "(5) the footer still counts the suites at 100 percent (one of the two)" || ck no "(5) footer: $(printf '%s\n' "$g2" | tail -1)"
echo "BANNER_RUN_BOARD arms=6 pass=$pass fail=$fail (tree $(git -C "$H" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 6 ] && { echo "GATE OK [$NAME]: a row shows the date and time range of its readings, and the delta column is last"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
