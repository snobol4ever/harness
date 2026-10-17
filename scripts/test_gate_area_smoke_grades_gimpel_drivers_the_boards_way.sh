#!/usr/bin/env bash
# test_gate_area_smoke_grades_gimpel_drivers_the_boards_way.sh -- THE AREA SMOKE GRADES A GIMPEL DRIVER THE WAY THE GIMPEL BOARD DOES (the
# coo 2026-10-03, on hq_snobol4's report area-smoke-gimpel-selects-79-runs-0). MEASURED CAUSE: test_area_smoke.sh for SCRIP 9411ee7d2
# read packages/snobol4/gimpel selected=79 of 145, run=0, and exited 0, with AREA_SMOKE_TABLE_SUITE_DISAGREEMENT: the package's ALL.sno
# container still holds the 120 entries cut before CEO-1269, while ALL.csv names the 145 drivers the board grades, so every landing whose
# map reached lang:snobol4 smoked zero Gimpel programs. THE CURE: the smoke delegates the gimpel table to test_snobol4_gimpel_suite.sh's
# smoke mode (S4E_AREA_SMOKE_ENTRIES), which grades the named drivers through scorecard_snobol4.sh exactly as the board does and writes no
# progress row and no score row; the one-runner guard admits that mode; and a smoke that selects entries and grades none now REFUSES.
# WHAT THIS GATE HOLDS, over the shared corpus read-only (a smoke is not a board, CEO-1342), four driver witnesses, modes m3 m4:
# (1) the smoke says it delegated, and every witness reads m3=PASS m4=PASS;
# (2) the smoke wrote no score row: SUITES.tsv and SCORE.md byte-identical before and after;
# (3) FAIL-ONCE, the pre-cure smoke (the harness with SMOKE_DELEGATES emptied, grading the container) names the table/suite disagreement
#     and REFUSES rc=2 on grading none -- where the harness before this landing graded none and exited 0.
# rc 2 when the binary, the runner or a witness is missing, or the smoke refuses.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || { echo "⛔ REFUSE(2): cannot cd to SCRIP root" >&2; exit 2; }
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ REFUSE(2): no lib_gate.sh" >&2; exit 2; }
GATE_NAME=area_smoke_grades_gimpel_drivers_the_boards_way; gate_parse_args "$@" 2>/dev/null || true
H="$HERE/corpus_suite_harness.py"
CORPUS="$(cd "$ROOT/.." && pwd)/corpus"; GH="$(cd "$ROOT/.." && pwd)/.github"
W="agt_driver asm360_driver bnorm_driver breakx_driver"
[ -x "$ROOT/scrip" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: no ./scrip -- run make"; exit 2; }
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
[ -f "$HERE/test_snobol4_gimpel_suite.sh" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: the gimpel runner is missing"; exit 2; }
for e in $W; do [ -f "$CORPUS/packages/snobol4/gimpel/$e.sno" ] && [ -f "$CORPUS/packages/snobol4/gimpel/$e.ref" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: witness $e has no program or ref"; exit 2; }; done
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export S4E_PROGRESS_OFF=1
smoke() {  # <harness> <out>
    python3 "$1" smoke DEFINE --tables packages/snobol4/gimpel --entries "$W" --modes m3,m4 > "$2" 2>&1; echo $?
}
red=0; n=0
arm() { n=$((n+1)); if [ "$2" = "$3" ]; then echo "  ok   $n $1: $2"; else echo "  FAIL $n $1: got '$2' want '$3'"; red=$((red+1)); fi; }
. "$ROOT/../harness/scripts/lib_suites_tsv.sh" || exit 2; mark="$(suites_real_mark)"
sig() { { md5sum < "$GH/SCORE.md"; suites_real_untouched "$mark" || echo moved; } 2>/dev/null | md5sum | cut -c1-12; }
before="$(sig)"
rc=$(smoke "$H" "$T/cure.out")
[ "$rc" = 2 ] && { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: the smoke refused:"; tail -6 "$T/cure.out"; exit 2; }
arm "the smoke delegates the gimpel table to its board's runner" "$(grep -c '^AREA_SMOKE_DELEGATED table=packages/snobol4/gimpel runner=test_snobol4_gimpel_suite.sh entries=4' "$T/cure.out")" "1"
for e in $W; do
    arm "$e the board's way" "$(grep -E "^AREA_SMOKE_ENTRY table=packages/snobol4/gimpel entry=$e " "$T/cure.out" | grep -oE 'm[34]=[A-Z]+' | tr '\n' ' ' | sed 's/ $//')" "m3=PASS m4=PASS"
done
arm "no score row written" "$(sig)" "$before"
# (3) fail-once: the same harness with the delegation table emptied grades the stale container
. "$HERE/lib_fixture_root.sh" || exit 2; fixture_root "$T/pre" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage a copied root at $T/pre"; exit 2; }
rm -f "$T/pre/harness/scripts/corpus_suite_harness.py"; sed 's/^SMOKE_DELEGATES = {.*}$/SMOKE_DELEGATES = {}/' "$H" > "$T/pre/harness/scripts/corpus_suite_harness.py"
if cmp -s "$H" "$T/pre/harness/scripts/corpus_suite_harness.py"; then arm "fail-once: the delegation is plantable" "no SMOKE_DELEGATES line" "a table emptied"
else
    # ⛔ THE STALE CONTAINER IS PLANTED, NOT ASSUMED (the coo 2026-10-09): this arm read the real package's container, which held the
    # 120 entries cut before CEO-1269 -- until corpus 0b8fac0c4 (10-03 17:44) re-cut Gimpel's container to its drivers, after which the
    # pre-cure smoke graded fine, exited 0, and this arm read red ('0 0 0') for six days with nothing wrong. A copy of the package whose
    # container holds one entry the table does not name is the disagreement this arm exists to see, on any corpus.
    P="$T/prehome"; mkdir -p "$P/corpus/packages/snobol4"; cp -r "$CORPUS/packages/snobol4/gimpel" "$P/corpus/packages/snobol4/"; ln -s "$GH" "$P/.github"
    find "$P/corpus/packages/snobol4/gimpel" -maxdepth 1 -name 'ALL.*' ! -name 'ALL.csv' -delete   # the container and its sidecars; the table stays
    python3 - "$P/corpus/packages/snobol4/gimpel" <<'PY'
import sys
d = sys.argv[1]; b = "*" + "-" * (80 - 1 - len(" 1 stale_entry")) + " 1 stale_entry"
open(d + "/ALL.sno", "w").write(b + "\n        OUTPUT = 'stale'\nEND\n")
open(d + "/ALL.ref", "w").write(b + "\nstale\n")
PY
    prc=$(S4E_HOME="$P" smoke "$T/pre/harness/scripts/corpus_suite_harness.py" "$T/pre.out")
    arm "fail-once: the container smoke names the disagreement and refuses on grading none" \
        "$prc $(grep -c '^AREA_SMOKE_TABLE_SUITE_DISAGREEMENT table=packages/snobol4/gimpel' "$T/pre.out") $(grep -c 'NONE graded' "$T/pre.out")" "2 1 1"
fi
echo "population: $n arm(s) over 4 Gimpel drivers ($W), modes m3 m4, the board's runner test_snobol4_gimpel_suite.sh in smoke mode"
if [ "$red" -eq 0 ]; then echo "GATE OK [$GATE_NAME]: the area smoke grades Gimpel drivers through the board's own loop, and writes no row"; gate_stamp 2>/dev/null; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $red of $n arm(s) red"; gate_stamp 2>/dev/null; exit 1
