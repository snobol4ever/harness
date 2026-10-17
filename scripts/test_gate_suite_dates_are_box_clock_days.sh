#!/usr/bin/env bash
# test_gate_suite_dates_are_box_clock_days.sh -- A SUITE ROW IS DATED ON THE BOX CLOCK, AND A READING CANNOT BE GRADED TOMORROW
# (row instruments-suite-banner-set-refuses-a-date-later-than-the-box-clock-day, CEO-1229, the coo).
# ⛔ THE DEFECT: .github 4f4ca80f, committed 19:59 CDT on 2026-09-23, wrote pat and pas-rungs dated 2026-09-24 -- the UTC day -- while
# fpc and pascal-bench-ref in the same commit read 2026-09-23. SUITES.tsv's dates are box-clock days (the box is America/Chicago), so a
# graded date a day ahead is a false label, and a like-for-like basis day can land a day late.
# THE CURE: util_suite_banner.py --set REFUSES rc=2 a DATE later than box_clock_day() -- the box's own zone, never the calling process's
# TZ -- and a --set that omits DATE takes that day; util_score_row.py dates its writes with its own _box_clock_day(), computed the same
# way (it no longer executes the banner file to borrow the function: a stub banner's sys.exit(0) once ended the writer with rc=0).
# ARMS (hermetic: a scratch copy of SUITES.tsv and SCORE.md; the real records are never written):
#   1 --set with TOMORROW's box-clock date REFUSES rc=2 and leaves the scratch table byte-identical; with TODAY's it lands
#   2 inside a process whose TZ is +14h and one at -12h, the banner's box_clock_day() and util_score_row.py's _box_clock_day() both
#     equal the box zone's own date -- the two functions agree, and neither follows the caller's zone
#   3 a --set that omits DATE, run from the +14h process, lands the BOX-CLOCK day, not the caller's
#   4 the real SUITES.tsv is byte-identical after the run
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=suite_dates_are_box_clock_days
GATE_STRICT=1
gate_parse_args "$@"
GH="$(cd "$ROOT/.." && pwd)/.github"; B="$GH/scripts/util_suite_banner.py"; SR="$HERE/util_score_row.py"
gate_require "$B" "util_suite_banner.py" || exit 2
gate_require "$SR" "util_score_row.py" || exit 2
. "$HERE/lib_suites_tsv.sh" || exit 2
gate_require "$SUITES_TSV_REAL" "the shared suite table" || exit 2
BOXTZ="$(cat /etc/timezone 2>/dev/null)"; [ -n "$BOXTZ" ] || BOXTZ="$(readlink /etc/localtime 2>/dev/null | sed 's#.*zoneinfo/##')"
[ -n "$BOXTZ" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot read the box's zone from /etc/timezone or /etc/localtime"; gate_stamp; exit 2; }
TODAY="$(TZ="$BOXTZ" date +%F)"; TOM="$(TZ="$BOXTZ" date -d tomorrow +%F)"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT INT TERM
REAL0="$(suites_real_mark)"
cp "$SUITES_TSV_REAL" "$GH/SCORE.md" "$W/"
K=$(awk -F'\t' '!/^#/ && $1!="key" && $9!="" {print $1; exit}' "$W/SUITES.tsv"); P=$(awk -F'\t' -v k="$K" '$1==k{print $9}' "$W/SUITES.tsv"); T=$(awk -F'\t' -v k="$K" '$1==k{print $10}' "$W/SUITES.tsv")
[ -n "$K" ] && [ -n "$T" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no graded row in SUITES.tsv to build the fixture on"; gate_stamp; exit 2; }
fails=0
ck() { if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
setb() { S4E_SUITES_TSV="$W/SUITES.tsv" S4E_SCORE_MD="$W/SCORE.md" python3 "$B" --set "$@"; }
cp "$W/SUITES.tsv" "$W/before.tsv"
o1=$(setb "$K" "$P" "$T" "$TOM" abc1234 2>&1 >/dev/null); r1=$?
cmp -s "$W/SUITES.tsv" "$W/before.tsv"; same=$?
setb "$K" "$P" "$T" "$TODAY" abc1234 >/dev/null 2>&1; r2=$?
ck "1 --set $K dated TOMORROW ($TOM) REFUSES rc=2 naming the box-clock day, table byte-identical; dated TODAY ($TODAY) it lands" \
   '[ "$r1" = 2 ] && [ "$same" = 0 ] && grep -q "later than the box-clock day $TODAY" <<<"$o1" && [ "$r2" = 0 ]'
b14=$(TZ=Pacific/Kiritimati python3 -c "import sys; sys.path.insert(0,'$GH/scripts'); import util_suite_banner as b; print(b.box_clock_day())" 2>&1)
s14=$(TZ=Pacific/Kiritimati python3 -c "import sys; sys.path.insert(0,'$HERE'); import util_score_row as u; print(u._box_clock_day())" 2>&1)
bm12=$(TZ=Etc/GMT+12 python3 -c "import sys; sys.path.insert(0,'$GH/scripts'); import util_suite_banner as b; print(b.box_clock_day())" 2>&1)
sm12=$(TZ=Etc/GMT+12 python3 -c "import sys; sys.path.insert(0,'$HERE'); import util_score_row as u; print(u._box_clock_day())" 2>&1)
ck "2 in +14h and -12h processes both functions read the box's day $TODAY (banner $b14 / $bm12, writer $s14 / $sm12)" \
   '[ "$b14" = "$TODAY" ] && [ "$s14" = "$TODAY" ] && [ "$bm12" = "$TODAY" ] && [ "$sm12" = "$TODAY" ]'
cp "$W/before.tsv" "$W/SUITES.tsv"
TZ=Pacific/Kiritimati S4E_SUITES_TSV="$W/SUITES.tsv" S4E_SCORE_MD="$W/SCORE.md" python3 "$B" --set "$K" "$P" "$T" >/dev/null 2>&1; r3=$?
d3=$(awk -F'\t' -v k="$K" '$1==k{print $8}' "$W/SUITES.tsv")
ck "3 a --set with no DATE from a +14h process lands the box-clock day (rc=$r3, dated $d3)" '[ "$r3" = 0 ] && [ "$d3" = "$TODAY" ]'
ck "4 the real SUITES.tsv is byte-identical to before this gate ran" 'suites_real_untouched "$REAL0"'
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: 4 arms -- suite rows are dated on the box clock ($BOXTZ)"; gate_stamp; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $fails of 4 arms red"; gate_stamp; exit 1
