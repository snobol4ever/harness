#!/usr/bin/env bash
# test_gate_sno_lex_compare_binary_safe.sh -- LGT/LLT/LGE/LLE/LEQ/LNE compare by the descriptor's carried length, never by a
# NUL-terminated scan: a NUL byte inside either operand is data (CHAR(0) values, REPLACE through a table whose image starts at
# &ALPHABET[0], captured slices). Graded in both modes against refs cut from the SPITBOL oracle on both call paths -- the
# compiled IR_CMP_TEST box (rt_cmp_d in rtx_arith.s) and the APPLY/OPSYN by-name path (core.c _LGT_ and its five siblings)
# (corpus/tests/snobol4/lexcmp_*.sno + .ref); the ref is re-cut live so oracle drift reads as a red, not a pass.
# rc=0 GREEN, rc=1 RED, rc=2 REFUSE (no oracle, no binary, or a zero denominator).
set -u
S4E="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$S4E/SCRIP" || exit 2
. ../harness/scripts/lib_oracle_flags.sh || exit 2
O="$(sbl_correctness_bin)" || { echo "REFUSE: no SPITBOL correctness oracle"; exit 2; }
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "REFUSE: no ./scrip or out/libscrip_rt.so (run make)"; exit 2; }
W="$S4E/corpus/tests/snobol4"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
n=0; red=0
for f in "$W"/lexcmp_*.sno; do
  [ -f "$f" ] || continue
  n=$((n+1)); b="$(basename "$f" .sno)"
  [ -f "$W/$b.ref" ] || { echo "RED $b: no committed ref"; red=$((red+1)); continue; }
  timeout -k 5 20 "$O" -bf "$f" </dev/null >"$T/$b.oref" 2>/dev/null
  cmp -s "$T/$b.oref" "$W/$b.ref" || { echo "RED $b: committed ref disagrees with the live oracle"; red=$((red+1)); continue; }
  timeout -k 5 20 ./scrip "$f" </dev/null >"$T/$b.m3" 2>/dev/null
  cmp -s "$T/$b.m3" "$W/$b.ref" || { echo "RED m3 $b: $(diff "$T/$b.m3" "$W/$b.ref" | grep -c '^[<>]') differing lines"; red=$((red+1)); }
  if timeout -k 5 60 ./scrip --compile -o "$T/$b.s" "$f" </dev/null >/dev/null 2>&1 && gcc -no-pie "$T/$b.s" -o "$T/$b.bin" -L./out -lscrip_rt -lm -Wl,-rpath,"$PWD/out" >/dev/null 2>&1; then
    timeout -k 5 20 "$T/$b.bin" </dev/null >"$T/$b.m4" 2>/dev/null
    cmp -s "$T/$b.m4" "$W/$b.ref" || { echo "RED m4 $b: $(diff "$T/$b.m4" "$W/$b.ref" | grep -c '^[<>]') differing lines"; red=$((red+1)); }
  else echo "RED m4 $b: compile or link failed"; red=$((red+1)); fi
done
[ "$n" -gt 0 ] || { echo "REFUSE: zero lexcmp_*.sno witnesses under $W"; exit 2; }
echo "LEXCMP witnesses=$n red=$red"
[ "$red" -eq 0 ] && { echo "GREEN: lexical comparators match the oracle on NUL-bearing operands in both modes (witnesses=$n)"; exit 0; }
echo "RED: lexical comparators diverge from the oracle (red=$red of $n x 2 modes)"; exit 1
