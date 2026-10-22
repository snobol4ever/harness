#!/usr/bin/env bash
# test_gate_snocone_oracle_road_cuts_the_committed_refs.sh -- `corpus_suite_harness.py capture-oracle-refs --lang snocone` (the transpile-then-SPITBOL road,
# snocone_oracle_run.sh) cuts, byte for byte, the ref a SncRungs entry already carries. (cfo, CEO-1868, on the ten one-statement entries it tightened: "A fail-once arm
# for it: cutting one of these ten with --lang snocone must reproduce the committed ref byte for byte.") The ten plus two printing entries so the road is not only read
# on a blank line. A ref comes from the oracle (SPITBOL's run of the SNOBOL4 text scrip --transpile writes), never from SCRIP's own run.
# ARM 1  each entry: extract it alone, cut its ref through the road in a scratch family, cmp with the committed ref -- identical.
# ARM 2  FAIL-ONCE, a proper test (CEO-1680): the same comparison against a COPY of a committed ref with one line appended must read DIFFERENT.
# ARM 3  the road RUNS the program it is handed: a copy of the first entry whose OUTPUT string is changed is cut to the changed answer, never to the committed ref.
# EXIT 0 green, 1 red (the entry and the arm named), 2 could not measure (named).
set -u
GATE=test_gate_snocone_oracle_road_cuts_the_committed_refs
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SUITE="$ROOT/corpus/tests/snocone"; HARNESS="$HERE/corpus_suite_harness.py"
ENTRIES="${GATE_ENTRIES:-simple_output_10 simple_output_17 simple_output_55 simple_output_59 simple_output_65 simple_output_67 simple_output_130 simple_output_134 simple_output_140 simple_output_142 simple_output_11 simple_output_104}"
refuse() { echo "⛔ REFUSED(2) [$GATE]: $*" >&2; exit 2; }
[ -f "$SUITE/ALL.sc" ] && [ -f "$SUITE/ALL.ref" ] && [ -f "$SUITE/ALL.csv" ] || refuse "no SncRungs suite at $SUITE"
[ -x "$ROOT/SCRIP/scrip" ] || refuse "no $ROOT/SCRIP/scrip -- make"
"$HERE/util_require_fresh.sh" --gate "$GATE" "$ROOT/SCRIP/scrip" "$ROOT/SCRIP/out/libscrip_rt.so" || exit 2
. "$HERE/lib_oracle_flags.sh" 2> /dev/null || refuse "cannot load lib_oracle_flags.sh"
[ -x "$(sbl_correctness_bin 2> /dev/null)" ] || refuse "no SPITBOL correctness oracle (sbl_correctness_bin)"
T="$(mktemp -d "${TMPDIR:-/tmp}/socr.XXXXXX")" || refuse "no scratch dir"; trap 'rm -rf "$T"' EXIT
cell() { python3 -I - "$SUITE/ALL.csv" "$1" "$2" <<'PY'
import csv, sys
for r in csv.DictReader(open(sys.argv[1], encoding='utf-8')):
    if r['entry'] == sys.argv[2]: print(r[sys.argv[3]]); break
PY
}
cut_entry() {   # $1 entry: leaves $T/$1.sc, $T/$1.committed and $T/$1.cut, or returns 2 when the entry cannot be materialised or cut
    local e="$1" ca; mkdir -p "$T/fam_$e"
    ( cd "$SUITE" && python3 "$HARNESS" extract ALL.sc ALL.ref "$e" "$T/$e.sc" --out-ref "$T/$e.committed" ) > "$T/$e.x.log" 2>&1 || return 2
    cp "$T/$e.sc" "$T/fam_$e/$e.sc"; ca="$(cell "$e" compile_args)"
    python3 "$HARNESS" capture-oracle-refs "$T/fam_$e" --lang snocone ${ca:+--compile-args="$ca"} > "$T/$e.cut.log" 2>&1 || return 2
    [ -f "$T/fam_$e/$e.ref" ] || return 2
    cp "$T/fam_$e/$e.ref" "$T/$e.cut"
}
RED=0; N=0; FIRST=""
for e in $ENTRIES; do
    cut_entry "$e"; rc=$?
    [ "$rc" -eq 0 ] || { echo "⛔ REFUSED(2) [$GATE]: $e could not be cut through the road (see $T/$e.cut.log): $(tail -2 "$T/$e.cut.log" 2> /dev/null | tr '\n' ' ' | cut -c1-200)" >&2; trap - EXIT; exit 2; }
    N=$((N + 1)); [ -n "$FIRST" ] || FIRST="$e"
    if cmp -s "$T/$e.cut" "$T/$e.committed"; then echo "  ARM 1 ok   $e: the road's cut equals the committed ref ($(wc -c < "$T/$e.cut") bytes)"
    else echo "  ARM 1 RED  $e: the road's cut differs from the committed ref"; diff <(od -c "$T/$e.committed") <(od -c "$T/$e.cut") | head -4; RED=1; fi
done
[ "$N" -ge 1 ] || refuse "no entry cut -- the other arms need one"
cp "$T/$FIRST.committed" "$T/corrupt.ref"; printf 'X\n' >> "$T/corrupt.ref"
if cmp -s "$T/$FIRST.cut" "$T/corrupt.ref"; then echo "  ARM 2 RED  the comparison cannot go red: a corrupted ref read identical to the cut of $FIRST"; RED=1; else echo "  ARM 2 ok   (fail-once) the cut of $FIRST against a corrupted copy of its ref reads DIFFERENT"; fi
mkdir -p "$T/fam_changed"; sed "s/'done'/'changed'/" "$T/$FIRST.sc" > "$T/fam_changed/$FIRST.sc"
cmp -s "$T/$FIRST.sc" "$T/fam_changed/$FIRST.sc" && refuse "ARM 3's edit did not change $FIRST's source ('done' absent)"
ca="$(cell "$FIRST" compile_args)"
python3 "$HARNESS" capture-oracle-refs "$T/fam_changed" --lang snocone ${ca:+--compile-args="$ca"} > "$T/changed.log" 2>&1 || refuse "ARM 3's changed copy could not be cut (see $T/changed.log)"
if cmp -s "$T/fam_changed/$FIRST.ref" "$T/$FIRST.committed"; then echo "  ARM 3 RED  a changed program was cut to the committed ref: the road does not run what it is handed"; RED=1
elif [ "$(cat "$T/fam_changed/$FIRST.ref")" = "$(printf '\nchanged')" ]; then echo "  ARM 3 ok   the changed program is cut to its own answer, not to the committed ref"
else echo "  ARM 3 RED  the changed program was cut to $(od -c "$T/fam_changed/$FIRST.ref" | head -1), not the answer SPITBOL gives"; RED=1; fi
if [ "$RED" -eq 0 ]; then echo "GATE GREEN [$GATE]: $N entries cut through scrip --transpile + sbl -bf equal their committed refs byte for byte"; exit 0; fi
echo "GATE RED [$GATE]"; exit 1
