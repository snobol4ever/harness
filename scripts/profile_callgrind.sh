#!/bin/bash
# profile_callgrind.sh — Ir attribution for a SCRIP-compiled (mode-4) binary, blob-vs-C split (RUNG SPD-0a).
# Usage: profile_callgrind.sh <prog-binary> <input-file> [outdir]
# Runtime-emitted pattern blobs live in anonymous pages — --smc-check=all-non-file is what counts them.
# Prints: total Ir, top functions, and the blob share (Ir attributed to addresses outside any file-backed object).
set -u
PROG=$1; INP=$2; OUT=${3:-/tmp/cg-$$}; mkdir -p "$OUT"
ulimit -s unlimited
# ⛔⭐ THE READING GOES THROUGH lib_ir_measure.sh.  This profiler used to run callgrind and print TOTAL_Ir
# with no exit-status check, so a binary that SEGVed produced a full attribution table -- top functions, blob
# share, percentage and all -- off the instructions of its dying path, in the same shape as an honest profile.
# ⭐ A blob share of a crash is not a small error, it is a confident answer to a question nobody asked.
. "$(dirname "${BASH_SOURCE[0]}")/lib_ir_measure.sh" 2>/dev/null || { echo "⛔ REFUSED (rc=2): cannot load lib_ir_measure.sh -- this profiler will not read Ir by hand"; exit 2; }
IRV=$(IR_OUT="$OUT/cg.out" IR_VG_FLAGS=--smc-check=all-non-file IR_PROG_OUT="$OUT/prog.out" IR_PROG_ERR="$OUT/valgrind.log" ir_measure "$PROG" < "$INP")
if ! ir_is_number "$IRV"; then echo "⛔ REFUSED (rc=2): $(ir_cell "$IRV") -- $(ir_reason "$IRV")"; echo "   (last lines of $OUT/valgrind.log)"; tail -5 "$OUT/valgrind.log" 2>/dev/null; exit 2; fi
TOTAL=$IRV
callgrind_annotate "$OUT/cg.out" 2>/dev/null | sed -n '/^-* *Ir/,/^$/p' | head -40 > "$OUT/top.txt"
BLOB=$(callgrind_annotate "$OUT/cg.out" 2>/dev/null | grep -E '\?\?\?|0x0000' | awk '{gsub(/,/,"",$1); s+=$1} END {print s+0}')
echo "TOTAL_Ir=$TOTAL BLOB_Ir=$BLOB BLOB_PCT=$(awk -v b="$BLOB" -v t="$TOTAL" 'BEGIN{if(t>0)printf "%.1f",100*b/t; else print 0}')"
echo "--- top functions ($OUT/top.txt) ---"
cat "$OUT/top.txt"
