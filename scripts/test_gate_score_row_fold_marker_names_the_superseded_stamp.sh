#!/usr/bin/env bash
export S4E_DB_CHECK_OVERRIDE="gate fixture: this gate plants no progress rows (util_score_row.py db_crosscheck, hq_raku 2026-09-16)"
# test_gate_score_row_fold_marker_names_the_superseded_stamp.sh -- A FOLDED TAIL NAMES ITS OWN DATE AND TREE, MACHINE-INSERTED
# (coo 2026-09-16; hq_prolog's third observation the same day, row util-score-row-board-write-folds-the-replaced-cells-tail-forward-
# as-provenance-without-a-machine-marker).
#
# THE DEFECT: util_score_row.py write folds the tail of the cell it replaces forward as provenance (CEO-475's one-archived-reading
# bound) under a fixed marker that says the tail is not asserted -- but not WHEN it was true or on WHICH tree.  hq_prolog's fresh
# rungs 542/563 shipped glued to prose reading '334 is DOWN from 340' from 2026-09-05, which a reader meets as current, and they
# hand-labelled the retained tail 'RETAINED PROVENANCE FROM THE SUPERSEDED 2026-09-05 READING (b812fb6d1)'.  A seat remembering to
# write that label is the failure mode.
#
# THE CURE UNDER TEST: supersede_marker() reads the replaced reading's own `<key>:` provenance clause and puts its hash, date and
# measurer into the marker, beside the fold's own date and writer -- so the tail reads 'superseded <today> by <seat>; the reading
# below was stamped <key>: SCRIP <hash> on <date> by <seat>' without anyone writing it.
#
# ARMS (the writer's own selftest, which plants a rebus floor cell, writes a lossy replacement over it and reads the fold back):
#   (a) the selftest proves the marker names the superseded reading's stamp and the fold's date
#   (b) the writer defines supersede_marker and the fold site calls it (the fixed SUPERSEDE_MARKER alone is the defect)
#   (c) the selftest wrote nothing to the real .github/SCORE.md
# FAIL_ONCE=1 blanks the selftest's proof line before arm (a) asserts, to prove the arm trips.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; GH="$HERE/../../.github"; HELPER="$HERE/util_score_row.py"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$HELPER" ] && [ -f "$GH/SCORE.md" ] || refuse "need $HELPER and the live .github/SCORE.md"
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: a folded SCORE.md tail names the superseded reading's own stamp, machine-inserted ==="
before="$(git -C "$GH" status --porcelain -- SCORE.md 2>/dev/null)"
out="$(env -u S4E_DONE_WHEN_RUN -u S4E_ONE_RUNNER_OVERRIDE timeout -k 5 900 python3 "$HELPER" selftest 2>&1)"; rc=$?
[ "$rc" = 124 ] && refuse "the writer's selftest timed out (load $(cut -d' ' -f1 /proc/loadavg)) -- not measured"
[ -n "${FAIL_ONCE:-}" ] && out="$(printf '%s\n' "$out" | grep -v "folded tail's marker names the superseded reading's own stamp")"
grep -q "the folded tail's marker names the superseded reading's own stamp" <<<"$out" && [ "$rc" = 0 ] \
  && ck ok "(a) the selftest proves the fold's marker names the superseded stamp and the fold's date (selftest rc=$rc)" \
  || ck no "(a) the selftest never proved the marker names the superseded stamp (rc=$rc): $(grep -m1 'SELFTEST FAIL' <<<"$out" | cut -c1-200)"
grep -q '^def supersede_marker' "$HELPER" && grep -q 'supersede_marker(cells\[PROV_COL\]' "$HELPER" \
  && ck ok "(b) the writer defines supersede_marker and the fold site calls it with the retired provenance" \
  || ck no "(b) the fold site no longer calls supersede_marker with the retired provenance -- the tail is unstamped again"
after="$(git -C "$GH" status --porcelain -- SCORE.md 2>/dev/null)"
[ "$before" = "$after" ] && ck ok "(c) the selftest left the real .github/SCORE.md as it found it" || ck no "(c) the selftest moved the real .github/SCORE.md ('$before' -> '$after')"
echo "population: $checks arm(s) graded, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [score_row_fold_marker_names_the_superseded_stamp]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [score_row_fold_marker_names_the_superseded_stamp]: $fails of $checks arms FAIL"; exit 1
