#!/usr/bin/env bash
# test_gate_area_smoke_grades_ipl_entries_the_boards_way.sh -- THE AREA SMOKE GRADES AN IPL ENTRY THE WAY THE IPL BOARD DOES (the coo
# 2026-10-02, row instruments-the-area-smoke-grades-ipl-entries-without-their-sidecars-and-reads-nine-false-reds, minted by the ceo).
# MEASURED CAUSE: the cfo's area smoke on 328bf9c9a read nine packages/icon/ipl entries NEW RED (webimage based cwd declchck farb
# hebcalen parens puzz xtable) against the board's PASS readings. The smoke graded the generated ALL.icn/ALL.ref container, which no
# runner maintains and which carries none of the per-program sidecars the board grades under (NAME.pin, the clock-and-entropy shim;
# NAME.dat stdin; NAME.argv; NAME.outfiles; fixtures; the isolation directory). Run the board's way by hand, farb parens puzz xtable
# read PASS. THE CURE: the smoke delegates the ipl table to test_icon_ipl_suite.sh's smoke mode (S4E_AREA_SMOKE_ENTRIES), which grades
# the named entries through the board's own loop and writes no progress row and no score row; the one-runner guard admits that mode.
# WHAT THIS GATE HOLDS, over the shared corpus read-only (a smoke is not a board, CEO-1342), witnesses progs/puzz progs/farb
# progs/parens progs/xtable, modes m3 m4:
# (1) the smoke says it delegated, and every witness reads m3=PASS m4=PASS;
# (2) the smoke wrote no score row: SUITES.tsv and SCORE.md byte-identical before and after;
# (3) FAIL-ONCE, the pre-cure smoke (the harness with SMOKE_DELEGATES emptied, grading the container) reads at least one witness red --
#     puzz seeds &random from &clock, which only the board's .pin shim fixes -- so arm 1 reds on the defect this gate names.
# rc 2 when the binary, the runner or a witness is missing, or the smoke refuses.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || { echo "⛔ REFUSE(2): cannot cd to SCRIP root" >&2; exit 2; }
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ REFUSE(2): no lib_gate.sh" >&2; exit 2; }
GATE_NAME=area_smoke_grades_ipl_entries_the_boards_way; gate_parse_args "$@" 2>/dev/null || true
H="$HERE/corpus_suite_harness.py"
CORPUS="$(cd "$ROOT/.." && pwd)/corpus"; GH="$(cd "$ROOT/.." && pwd)/.github"
W="progs/puzz progs/farb progs/parens progs/xtable"
[ -x "$ROOT/scrip" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: no ./scrip -- run make"; exit 2; }
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
[ -f "$HERE/test_icon_ipl_suite.sh" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: the IPL runner is missing"; exit 2; }
for e in $W; do [ -f "$CORPUS/packages/icon/ipl/$e.icn" ] && [ -f "$CORPUS/packages/icon/ipl/$e.ref" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: witness $e has no program or ref"; exit 2; }; done
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export S4E_PROGRESS_OFF=1
smoke() {  # <harness> <out>
    python3 "$1" smoke write --tables packages/icon/ipl --entries "$W" --modes m3,m4 > "$2" 2>&1; echo $?
}
red=0; n=0
arm() { n=$((n+1)); if [ "$2" = "$3" ]; then echo "  ok   $n $1: $2"; else echo "  FAIL $n $1: got '$2' want '$3'"; red=$((red+1)); fi; }
. "$ROOT/../harness/scripts/lib_suites_tsv.sh" || exit 2; mark="$(suites_real_mark)"
sig() { { md5sum < "$GH/SCORE.md"; suites_real_untouched "$mark" || echo moved; } 2>/dev/null | md5sum | cut -c1-12; }
before="$(sig)"
rc=$(smoke "$H" "$T/cure.out")
[ "$rc" = 2 ] && { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: the smoke refused:"; tail -6 "$T/cure.out"; exit 2; }
arm "the smoke delegates the ipl table to its board's runner" "$(grep -c '^AREA_SMOKE_DELEGATED table=packages/icon/ipl runner=test_icon_ipl_suite.sh entries=4' "$T/cure.out")" "1"
for e in $W; do
    arm "$e the board's way" "$(grep -E "^AREA_SMOKE_ENTRY table=packages/icon/ipl entry=$e " "$T/cure.out" | grep -oE 'm[34]=[A-Z]+' | tr '\n' ' ' | sed 's/ $//')" "m3=PASS m4=PASS"
done
arm "no score row written" "$(sig)" "$before"
# (3) fail-once: the same harness with the delegation table emptied grades the container
. "$HERE/lib_fixture_root.sh" || exit 2; fixture_root "$T/pre" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage a copied root at $T/pre"; exit 2; }
rm -f "$T/pre/harness/scripts/corpus_suite_harness.py"; sed 's/^SMOKE_DELEGATES = {.*}$/SMOKE_DELEGATES = {}/' "$H" > "$T/pre/harness/scripts/corpus_suite_harness.py"
if cmp -s "$H" "$T/pre/harness/scripts/corpus_suite_harness.py"; then arm "fail-once: the delegation is plantable" "no SMOKE_DELEGATES line" "a table emptied"
else
    S4E_HOME="$(cd "$ROOT/.." && pwd)" smoke "$T/pre/harness/scripts/corpus_suite_harness.py" "$T/pre.out" >/dev/null
    nred=$(grep -E '^AREA_SMOKE_ENTRY table=packages/icon/ipl ' "$T/pre.out" | grep -cvE 'm3=PASS m4=PASS')
    arm "fail-once: the container smoke reads a witness red" "$([ "$nred" -ge 1 ] && echo red || echo "green ($nred red)") $(grep -c '^AREA_SMOKE_DELEGATED' "$T/pre.out")" "red 0"
fi
echo "population: $n arm(s) over 4 IPL witnesses ($W), modes m3 m4, the board's runner test_icon_ipl_suite.sh in smoke mode"
if [ "$red" -eq 0 ]; then echo "GATE OK [$GATE_NAME]: the area smoke grades IPL entries through the board's own loop and sidecars, and writes no row"; gate_stamp 2>/dev/null; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $red of $n arm(s) red"; gate_stamp 2>/dev/null; exit 1
