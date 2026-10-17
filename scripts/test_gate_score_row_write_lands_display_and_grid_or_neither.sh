#!/usr/bin/env bash
export S4E_DB_CHECK_OVERRIDE="gate fixture: this gate plants no progress rows (util_score_row.py db_crosscheck, hq_raku 2026-09-16)"
# test_gate_score_row_write_lands_display_and_grid_or_neither.sh -- ONE MEASUREMENT, TWO CELLS, ONE WRITE: a V/M write moves the
# suite's fraction in the display cell AND in the grid cell it mirrors, the grid's own prose kept, and reads both back (coo 2026-09-16;
# hq_pascal's two witnesses the same day, PAT 297 display / 296 grid V and 271 / 283 the other way; row util-score-row-write-can-leave-
# the-grid-cell-behind-the-display-cell-or-the-display-behind-the-grid-two-writers-one-measurement).
#
# THE DEFECT: util_score_row.py write mirrored the display into the grid, but a grid clause whose fraction differed from the write
# (a CONFLICT) or a grid cell carrying prose was left untouched BY DESIGN, so the display landed alone and only test_gate_score_
# tables_agree noticed, after the fact, by value.
#
# ARMS (a scratch .github shaped as a clone with an origin -- a plain copy is exempt from the lane guard -- copied from the live files
# whose Pascal display and grid V cells both carry PAT 296/427 today, or whatever they carry: the fixture reads the grid's PAT fraction
# and writes N+1 over the same denominator; a scratch MODE names pascal=hq_pascal; S4E_SEAT=hq_pascal):
#   (a) the write lands: the display's PAT fraction and the grid V cell's PAT fraction both read the new value; no old reading remains
#   (b) the grid cell's own provenance prose (its SCRIP/corpus/RT_OPT clause) survives the move
#   (c) the writer says the grid fraction moved in place, and a --check of the mirror by value (test_gate_score_tables_agree's rule:
#       same denominator, same numerator) holds on the scratch pair
# FAIL_ONCE=1 puts the grid V cell's PAT fraction back to the old value after the write, before arm (a) asserts, to prove it trips.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; GH="$HERE/../../.github"; HELPER="$HERE/util_score_row.py"
. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh" || { echo "REFUSED(2): cannot load lib_suites_tsv.sh"; exit 2; }
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$HELPER" ] && [ -f "$GH/SCORE.md" ] && [ -f "$SUITES_TSV_REAL" ] && [ -f "$GH/scripts/util_suite_banner.py" ] || refuse "need $HELPER and the live .github files"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_two_cells.XXXXXX")" || refuse "mktemp failed"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/.github/scripts"; cp "$GH/SCORE.md" "$SUITES_TSV_REAL" "$W/.github/"; cp "$GH/scripts/util_suite_banner.py" "$W/.github/scripts/"
( cd "$W/.github" && git init -q && git add -A && git -c user.name=fixture -c user.email=f@x commit -q -m fixture && git remote add origin "file://$W/.github" ) || refuse "could not shape the scratch .github as a clone"
MODE="$W/MODE"; printf 'DECTET\n# fixture\nLANES: pascal=hq_pascal\n' > "$MODE"
MD="$W/.github/SCORE.md"
gl="$(grep -n '^| pascal |' "$MD" | sed -n 2p | cut -d: -f1)"; dl="$(grep -n '^| pascal |' "$MD" | sed -n 1p | cut -d: -f1)"
[ -n "$gl" ] && [ -n "$dl" ] || refuse "SCORE.md carries fewer than two '| pascal |' rows (display + grid)"
old="$(sed -n "${gl}p" "$MD" | grep -oE 'PAT[^|]{0,200}' | head -1 | grep -oE '[0-9]+/[0-9]+' | head -1)"; [ -n "$old" ] || refuse "the grid V cell for pascal carries no PAT fraction to move"
n="${old%%/*}"; d="${old##*/}"; new="$((n+1))/$d"
echo "    fixture: grid V PAT reads $old; the write states $new (display line $dl, grid line $gl)"
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: a V write lands the display cell AND its grid mirror, or neither ==="
export S4E_SEAT=hq_pascal   # the one call shape below reads it (test_gate_seat_identity_one_map ARM 5)
out="$(env -u S4E_DONE_WHEN_RUN -u S4E_ONE_RUNNER_OVERRIDE S4E_HOME="$W" S4E_MODE_FILE="$MODE" python3 "$HELPER" write --lang pascal --column vendor --suite PAT --modes m3,m4 --measurer "${S4E_SEAT:-}" --text "PAT: ISO 7185 validation suite (Pascal-P5 1.4.x, vendored corpus/packages/pascal/pat): both-modes $new · m3 $new · m4 $new (test_pascal_pat_suite.sh, gate fixture)" --suite-pass "$((n+1))" --suite-total "$d" 2>&1)"; rc=$?
[ -n "${FAIL_ONCE:-}" ] && sed -i "${gl}s#$new#$old#" "$MD"
dfr="$(sed -n "${dl}p" "$MD" | grep -oE 'PAT[^|]{0,200}' | head -1 | grep -oE '[0-9]+/[0-9]+' | sort -u | tr '\n' ' ')"
gfr="$(sed -n "${gl}p" "$MD" | grep -oE 'PAT[^|]{0,200}' | head -1 | grep -oE '[0-9]+/[0-9]+' | sort -u | tr '\n' ' ')"
[ "$rc" = 0 ] && [ "$dfr" = "$new " ] && [ "$gfr" = "$new " ] && ck ok "(a) both cells moved: display PAT [$dfr] grid V PAT [$gfr], no old reading remains" || ck no "(a) rc=$rc display=[$dfr] grid=[$gfr] -- got: $(grep -E 'grid V|REFUSED|PARTIAL' <<<"$out" | head -2 | cut -c1-200)"
sed -n "${gl}p" "$MD" | grep -oE 'PAT[^|]{0,300}' | grep -q 'RT_OPT' && ck ok "(b) the grid cell's own provenance prose (RT_OPT clause) survived the move" || ck no "(b) the grid PAT clause lost its provenance prose: $(sed -n "${gl}p" "$MD" | grep -oE 'PAT[^|]{0,160}' | head -1)"
grep -q 'fraction moved in place with the display' <<<"$out" && ck ok "(c) the writer said the grid fraction moved in place with the display" || ck no "(c) the writer did not report the in-place move -- got: $(grep -E 'grid V' <<<"$out" | head -2 | cut -c1-200)"
echo "population: $checks arm(s) graded, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [score_row_write_lands_display_and_grid_or_neither]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [score_row_write_lands_display_and_grid_or_neither]: $fails of $checks arms FAIL"; exit 1
