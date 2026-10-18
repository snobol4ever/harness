#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the scorecard's one verb invoked as an instrument fixture over a scratch corpus, not a board (CEO-523)"
# test_gate_gimpel_runner_masks_the_engine_clock_lines.sh -- THE GIMPEL RUNNER READS THE PACKAGE'S ALL.mask BEFORE IT COMPARES (the coo
# 2026-10-02, row instruments-the-gimpel-runner-reads-all-mask-so-timer-and-timegc-grade-their-pinned-lines, ceo CEO-1412). MEASURED CAUSE:
# scorecard_snobol4.sh grade() was a plain cmp, so the CEO-409 rows corpus f2ae706da declared for gimpel's timegc_driver (the engine clock
# and the storage units COLLECT() frees) were never applied and timegc read DIFF DIFF on every pass; with the mask applied it reads PASS
# PASS (the ceo by hand, then this seat through the runner). WHAT THIS GATE HOLDS, over a scratch corpus outside corpus/ (CEO-547) holding
# timegc_driver, its two includes, its ref, its ALL.csv row and its two ALL.mask rows, graded through the runner's own `one` verb:
# (1) with the mask, PASS in both modes, and the note column counts the masked lines on both sides;
# (2) PLANTED, the same fixture with an ALL.mask that has no timegc row -- an unmasked timing difference -- reads DIFF in both modes;
# (3) FAIL-ONCE, the scorecard with grade()'s SCRIP-side mask step removed (the pre-cure compare) reads DIFF on arm 1's fixture, so arm 1
# would red on the defect this gate names. rc 2 when the oracle, the binary or a fixture file is missing.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || { echo "⛔ REFUSE(2): cannot cd to SCRIP root" >&2; exit 2; }
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ REFUSE(2): no lib_gate.sh" >&2; exit 2; }
GATE_NAME=gimpel_runner_masks_the_engine_clock_lines; gate_parse_args "$@" 2>/dev/null || true
SRC="${CORPUS:-$(cd "$ROOT/.." && pwd)/corpus}/packages/snobol4/gimpel"
SCORE="$HERE/scorecard_snobol4.sh"
[ -f "$SCORE" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: $SCORE is missing"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: no ./scrip -- run make"; exit 2; }
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
for f in timegc_driver.sno timegc_driver.ref timegc.inc resoluti.inc system.inc ALL.mask ALL.csv; do
    [ -f "$SRC/$f" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: $SRC/$f is missing -- the fixture cannot be built"; exit 2; }
done
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fixture() {  # <corpus dir> <mask rows: real|none>
    local g="$1/packages/snobol4/gimpel"; mkdir -p "$g"
    cp "$SRC"/{timegc_driver.sno,timegc_driver.ref,timegc.inc,resoluti.inc,system.inc} "$g/"
    { head -1 "$SRC/ALL.csv"; grep -E '^[0-9]+,timegc_driver,' "$SRC/ALL.csv"; } > "$g/ALL.csv"
    if [ "$2" = real ]; then grep -E '^timegc_driver	' "$SRC/ALL.mask" > "$g/ALL.mask"; else grep -vE '^timegc_driver	' "$SRC/ALL.mask" | head -3 > "$g/ALL.mask"; fi
}
fixture "$T/masked" real; fixture "$T/unmasked" none
nmask=$(wc -l < "$T/masked/packages/snobol4/gimpel/ALL.mask")
[ "$nmask" -ge 1 ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: corpus gimpel ALL.mask carries no timegc_driver row -- nothing to hold"; exit 2; }
one() {  # <scorecard> <corpus> -> the run_one row
    CORPUS="$2" S4E_SEAT="${S4E_SEAT:-coo}" bash "$1" one gimpel timegc_driver 2>/dev/null | awk -F'\t' '$4=="gimpel"' | tail -1
}
red=0; n=0
arm() { n=$((n+1)); if [ "$2" = "$3" ]; then echo "  ok   $n $1: $2"; else echo "  FAIL $n $1: got '$2' want '$3'"; red=$((red+1)); fi; }
r1="$(one "$SCORE" "$T/masked")"
[ -n "$r1" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: the runner printed no row for timegc_driver -- cannot measure"; exit 2; }
case "$(cut -f6 <<<"$r1")" in ORACLE_FAIL|MASK_REFUSED) echo "⛔ GATE REFUSE(2) [$GATE_NAME]: $(cut -f6- <<<"$r1")"; exit 2;; esac
arm "masked: both modes" "$(cut -f6,7 <<<"$r1" | tr '\t' ' ')" "PASS PASS"
arm "masked: the note counts both sides" "$(cut -f10 <<<"$r1" | grep -oE 'masked:(pin|live)=[0-9]+|m3=[0-9]+|m4=[0-9]+' | sed 's/=.*//; s/masked://' | sort -u | tr '\n' ' ' | sed 's/ $//')" "live m3 m4 pin"
r2="$(one "$SCORE" "$T/unmasked")"
arm "planted unmasked timing difference" "$(cut -f6,7 <<<"$r2" | tr '\t' ' ')" "DIFF DIFF"
. "$HERE/lib_fixture_root.sh" || exit 2; fixture_root "$T/pre" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage a copied root at $T/pre"; exit 2; }
rm -f "$T/pre/harness/scripts/scorecard_snobol4.sh"; grep -v 'sc_mask "$mfile" "$n" scrip' "$SCORE" > "$T/pre/harness/scripts/scorecard_snobol4.sh"
if cmp -s "$SCORE" "$T/pre/harness/scripts/scorecard_snobol4.sh"; then arm "fail-once: the pre-cure compare is plantable" "no SCRIP-side mask step found" "a mask step removed"
else r3="$(one "$T/pre/harness/scripts/scorecard_snobol4.sh" "$T/masked")"; arm "fail-once: the pre-cure compare" "$(cut -f6,7 <<<"$r3" | tr '\t' ' ')" "DIFF DIFF"; fi
echo "population: $n arm(s) over timegc_driver ($nmask mask row(s)), modes m3 m4, oracle sbl -bf"
if [ "$red" -eq 0 ]; then echo "GATE OK [$GATE_NAME]: the gimpel runner applies ALL.mask to the oracle side and each SCRIP mode before it compares"; gate_stamp 2>/dev/null; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $red of $n arm(s) red"; gate_stamp 2>/dev/null; exit 1
