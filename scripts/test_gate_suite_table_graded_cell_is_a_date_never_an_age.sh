#!/usr/bin/env bash
# test_gate_suite_table_graded_cell_is_a_date_never_an_age.sh -- THE SUITE TABLE'S "graded" CELL IS THE DATE OF THE GRADING, NEVER AN AGE
# RECKONED AGAINST THE DAY OF THE RENDER (row instruments-score-md-graded-cell-freezes-a-relative-age-so-a-row-not-re-rendered-today-
# still-reads-today, the coo 2026-09-23; Lon 2026-09-13: "Add the date of the grading for each test suite. Say when was the last time
# the test was run which produced the results which are being reported.").
# ⛔ THE DEFECT: .github/scripts/util_suite_banner.py md() wrote '<date> (today|yesterday|N days ago)', and --set re-renders only the
# row a run measured, so every other row kept the age it was written with: on 2026-09-23 all 26 cells of SCORE.md read '(today)', among
# them Dotnet, TPgm and Roast graded 2026-09-16. A date cannot go stale; an age written into a file can.
# ARMS (hermetic -- a scratch SUITES.tsv and SCORE.md; only arm 3 reads the real SCORE.md, and it writes nothing):
#   1 rows graded today, yesterday and seven days ago each render their graded cell as exactly '| <date> |'
#   2 no rendered line carries '(today)', '(yesterday)' or '(N days ago)'
#   3 the committed .github/SCORE.md suite table carries no such age either
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=suite_table_graded_cell_is_a_date_never_an_age
GATE_STRICT=1
gate_parse_args "$@"
GH="$(cd "$ROOT/.." && pwd)/.github"; B="$GH/scripts/util_suite_banner.py"
gate_require "$B" "util_suite_banner.py" || exit 2
gate_require "$GH/SCORE.md" ".github/SCORE.md" || exit 2
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT INT TERM
D0=$(date +%F); D1=$(date -d yesterday +%F); D7=$(date -d '7 days ago' +%F)
{ printf 'key\tnick\temoji\tlang\tfirst_date\tfirst_pass\tfirst_total\ttoday_date\ttoday_pass\ttoday_total\ttree\tcriterion_changed\n'
  printf 'fx0\tFxToday\tx\tsnobol4\t%s\t1\t2\t%s\t1\t2\tabc1234\t\n' "$D7" "$D0"
  printf 'fx1\tFxYest\tx\tsnobol4\t%s\t1\t2\t%s\t1\t2\tabc1234\t\n' "$D7" "$D1"
  printf 'fx7\tFxWeek\tx\tsnobol4\t%s\t1\t2\t%s\t1\t2\tabc1234\t\n' "$D7" "$D7"; } > "$W/SUITES.tsv"
out=$(S4E_SUITES_TSV="$W/SUITES.tsv" S4E_DEFERRED_TSV="$W/none.tsv" python3 "$B" --md 2>&1); rc=$?
[ "$rc" = 0 ] && grep -q '^| suite | lang |' <<<"$out" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the renderer did not render (rc=$rc): $(printf '%s\n' "$out" | head -2)"; gate_stamp; exit 2; }
fails=0
ck() { if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
ck "1 today / yesterday / seven days ago each render exactly '| <date> |'" 'grep -q "^| FxToday | snobol4 | 1/2 | $D0 | " <<<"$out" && grep -q "^| FxYest | snobol4 | 1/2 | $D1 | " <<<"$out" && grep -q "^| FxWeek | snobol4 | 1/2 | $D7 | " <<<"$out"'
AGE='\| [0-9]{4}-[0-9]{2}-[0-9]{2} \((today|yesterday|[0-9]+ days ago)\) \|'
ck "2 no rendered cell carries an age relative to the day of the render" '! grep -qE "$AGE" <<<"$out"'
ck "3 the committed SCORE.md suite table carries no such age ($(grep -cE "$AGE" "$GH/SCORE.md") found)" '! grep -qE "$AGE" "$GH/SCORE.md"'
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: 3 arms -- the graded cell is a date"; gate_stamp; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $fails of 3 arms red"; printf '%s\n' "$out" | sed 's/^/    /' | head -8; gate_stamp; exit 1
