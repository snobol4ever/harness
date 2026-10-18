#!/usr/bin/env bash
# witness_aisnobol_test.sh -- ONE PACKAGE PROGRAM GRADED THE WAY ITS RUNNER GRADES IT (ceo, 2026-10-18): the aisnobol package's
# TEST (818 lines, its own TEST.IN, --stlimit, the SPITCORE library through SNO_LIB, and spitlib.idx that BUILDLIB writes first).
# The coo's verifier read it CRASH in both modes at c200347cc as a first reading; run by hand outside the package it refuses on
# the include and says nothing -- this script stages the package the way test_snobol4_aisnobol_suite.sh does, so a seat's
# DONE-WHEN can name one program of a package without running the board. The monitor bracket (monitor_run.sh TEST.sno --oracle
# --input TEST.IN in the staged copy) read 35601 steps in agreement and the first divergence at SPITCORE.sno:160 (|'' after
# LISTARG's conditional RETURN; SCRIP reports RETURN NULL and dies SIGSEGV at pc 0x2, the oracle prints and goes on).
# USE: bash harness/scripts/witness_aisnobol_test.sh [--mode m3|m4]   (default both)
# rc 0 both modes match the ref; 1 a mode differs or crashes (the diff's head is printed); 2 cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
PKG="$(cd "$HERE/../../corpus/packages/snobol4/aisnobol" 2>/dev/null && pwd)" || { echo "REFUSE(2): no aisnobol package beside harness"; exit 2; }
[ -x "$SCRIP/scrip" ] || { echo "REFUSE(2): $SCRIP/scrip is not built"; exit 2; }
MODES="m3 m4"; while [ $# -gt 0 ]; do case "$1" in --mode) MODES="$2"; shift;; *) echo "REFUSE(2): unknown argument $1"; exit 2;; esac; shift; done
W="$(mktemp -d "${TMPDIR:-/tmp}/witness_aisnobol.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
python3 "$HERE/corpus_suite_harness.py" extract "$PKG/ALL.sno" "$PKG/ALL.ref" TEST "$W/TEST.sno" --out-ref "$W/TEST.ref" --out-in "$W/TEST.in" > "$W/extract.log" 2>&1 || { echo "REFUSE(2): extract of TEST failed: $(tail -1 "$W/extract.log" | cut -c1-120)"; exit 2; }
cp -a "$PKG"/. "$W/pkg/" 2>/dev/null || mkdir -p "$W/pkg"; cp -a "$PKG"/. "$W/pkg/"
export SNO_LIB="$W/pkg"
SW="-d131072k -s4096k --stlimit"
( cd "$W/pkg" && timeout -k 2 20 "$SCRIP/scrip" $SW BUILDLIB.sno < /dev/null > /dev/null 2>&1 ) || { echo "REFUSE(2): BUILDLIB (the library index TEST reads) did not run"; exit 2; }
[ -f "$W/pkg/spitlib.idx" ] || { echo "REFUSE(2): BUILDLIB wrote no spitlib.idx"; exit 2; }
rc=0
for m in $MODES; do
    case "$m" in
        m3) ( cd "$W/pkg" && timeout -k 2 20 "$SCRIP/scrip" $SW TEST.sno < "$W/TEST.in" > "$W/TEST.$m.out" 2> "$W/TEST.$m.err" ); r=$?;;
        m4) ( cd "$W/pkg" && "$SCRIP/scrip" --compile $SW -o "$W/TEST.s" TEST.sno < /dev/null > /dev/null 2> "$W/TEST.c.err" && gcc "$W/TEST.s" -L"$SCRIP/out" -lscrip_rt -lm -Wl,-rpath,"$SCRIP/out" -o "$W/TEST.bin" 2>> "$W/TEST.c.err" && timeout -k 2 20 "$W/TEST.bin" < "$W/TEST.in" > "$W/TEST.$m.out" 2> "$W/TEST.$m.err" ); r=$?;;
        *) echo "REFUSE(2): mode $m"; exit 2;;
    esac
    if [ "$r" -eq 0 ] && cmp -s "$W/TEST.$m.out" "$W/TEST.ref"; then echo "AISNOBOL_TEST mode=$m PASS lines=$(wc -l < "$W/TEST.$m.out")"
    else rc=1; echo "AISNOBOL_TEST mode=$m RED rc=$r lines=$(wc -l < "$W/TEST.$m.out" 2>/dev/null || echo 0) of $(wc -l < "$W/TEST.ref") $(tail -c 160 "$W/TEST.$m.err" 2>/dev/null | tr '\n' ' ')"; diff "$W/TEST.$m.out" "$W/TEST.ref" | head -4 | cut -c1-100; fi
done
[ "$rc" -eq 0 ] && echo "WITNESS PASS [aisnobol TEST]: both modes print the oracle's 823 lines" || echo "WITNESS RED [aisnobol TEST]: see the mode lines above; bracket: monitor_run.sh TEST.sno --oracle --input TEST.IN in a staged copy of the package"
exit $rc
