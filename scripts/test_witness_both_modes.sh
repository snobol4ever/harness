#!/bin/bash
# test_witness_both_modes.sh -- ONE PROGRAM, BOTH MODES, AGAINST ITS REF (ceo CEO-1948): a DONE-WHEN for a red the language board cannot hand a seat.
# Usage, from SCRIP: bash ../harness/scripts/test_witness_both_modes.sh <src> <ref> [<src> <ref> ...]
# Each source is run in mode 3 (./scrip <src>) and in mode 4 (./scrip --compile -o, linked the harness's way, run) from its own directory, stdin
# /dev/null, and its stdout compared byte for byte with <ref>. Prints WITNESS <mode> <PASS|FAIL rc=N> <src> per run and WITNESS_TOTAL pass= fail=.
# rc 0 every run equal to its ref; rc 1 any run differs or crashes; rc 2 cannot measure (no ./scrip or out/libscrip_rt.so, a missing file, no pair).
# NOT THIS RUNNER'S SHAPE (the cfo, 2026-10-25): a corpus benchmark kernel with a <stem>.dat/.fasta (stdin), <stem>.argv (column 2 is its argv) or
# <stem>.heap/.stack sidecar -- this runner feeds /dev/null, no argv and no -d/-s, so such a kernel reads FAIL rc=0 here on every tree (12 of 16 scanning
# kernels did, identical on the cut under review and on origin); grade it through bench_<lang>_bar.sh or with its sidecars by hand, and read a FAIL that
# is identical on both trees as the runner's shape, never as the landing's red.
HERE="$(cd "$(dirname "$0")" && pwd)"; SCRIP_DIR="$HERE/../../SCRIP"; SCRIP_BIN="$SCRIP_DIR/scrip"; RT="$SCRIP_DIR/out"
[ -x "$SCRIP_BIN" ] && [ -f "$RT/libscrip_rt.so" ] || { echo "REFUSE(2): no $SCRIP_BIN or $RT/libscrip_rt.so -- run make -j8 in SCRIP"; exit 2; }
[ $# -ge 2 ] && [ $(( $# % 2 )) -eq 0 ] || { echo "REFUSE(2): usage: test_witness_both_modes.sh <src> <ref> [<src> <ref> ...]"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; pass=0; fail=0
while [ $# -ge 2 ]; do
  src="$(readlink -f "$1")"; ref="$(readlink -f "$2")"; shift 2
  [ -f "$src" ] && [ -f "$ref" ] || { echo "REFUSE(2): missing $src or $ref"; exit 2; }
  d="$(dirname "$src")"; b="$(basename "$src")"
  ( cd "$d" && timeout -k 2 60 "$SCRIP_BIN" "$b" < /dev/null > "$T/m3.out" 2> "$T/m3.err" ); r3=$?
  if [ $r3 -lt 124 ] && cmp -s "$T/m3.out" "$ref"; then echo "WITNESS m3 PASS $src"; pass=$((pass+1)); else echo "WITNESS m3 FAIL rc=$r3 $src"; fail=$((fail+1)); fi
  r4=0; ( cd "$d" && timeout -k 2 120 "$SCRIP_BIN" --compile -o "$T/w.s" "$b" < /dev/null > /dev/null 2> "$T/m4c.err" ) || r4=$?
  [ $r4 -eq 0 ] && { gcc "$T/w.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$T/w" 2> "$T/m4l.err" || r4=98; }
  [ $r4 -eq 0 ] && { ( cd "$d" && timeout -k 2 60 "$T/w" < /dev/null > "$T/m4.out" 2> "$T/m4.err" ); r4=$?; }
  if [ $r4 -lt 124 ] && [ -f "$T/m4.out" ] && cmp -s "$T/m4.out" "$ref"; then echo "WITNESS m4 PASS $src"; pass=$((pass+1)); else echo "WITNESS m4 FAIL rc=$r4 $src"; fail=$((fail+1)); fi
  rm -f "$T/m4.out" "$T/w" "$T/w.s"
done
echo "WITNESS_TOTAL pass=$pass fail=$fail"; [ $fail -eq 0 ]
