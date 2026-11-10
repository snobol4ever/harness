#!/usr/bin/env bash
# test_gate_sno_deferred_replacement_keeps_its_capture_mark.sh -- a REPLACEMENT statement whose pattern is a pattern-valued VARIABLE carrying a capture: the deferred
# pattern's success landing stored the scan hit start at a spine-relative slot inside the live match RBP frame, i.e. on the saved capture mark, and the
# SPITBOL oracle (the master corpus/tests/snobol4/ALL.{sno,ref}, origins dcap_repl_*, extracted by origin); the ref is re-cut live so oracle drift reads as a red, not a pass.
# rc=0 GREEN, rc=1 RED, rc=2 REFUSE (no oracle, no binary, or a zero denominator).
set -u
S4E="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$S4E/SCRIP" || exit 2
. ../harness/scripts/lib_oracle_flags.sh || exit 2
O="$(sbl_correctness_bin)" || { echo "REFUSE: no SPITBOL correctness oracle"; exit 2; }
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "REFUSE: no ./scrip or out/libscrip_rt.so (run make)"; exit 2; }
W="$S4E/corpus/tests/snobol4"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# THE WITNESSES ARE MASTER ENTRIES: each is extracted by ORIGIN (the durable key in ALL.csv; the builder re-sorts entry names) from $W/ALL.{sno,ref} into scratch.
WIT="dcap_repl_deferred_capture_into_global dcap_repl_deferred_capture_into_result dcap_repl_deferred_capture_then_return dcap_repl_deferred_pattern_built_by_function"
for b in $WIT; do
  timeout -k 5 60 python3 "$S4E/harness/scripts/corpus_suite_harness.py" extract "$W/ALL.sno" "$W/ALL.ref" --origin "$b" "$T/$b.sno" --out-ref "$T/$b.ref" </dev/null >/dev/null 2>&1
  [ -f "$T/$b.sno" ] && [ -f "$T/$b.ref" ] || { echo "REFUSE: witness $b is not extractable by origin from $W/ALL.{sno,ref}"; exit 2; }
done
n=0; red=0
for b in $WIT; do
  f="$T/$b.sno"
  n=$((n+1))
  timeout -k 5 20 "$O" -bf "$f" </dev/null >"$T/$b.oref" 2>/dev/null
  cmp -s "$T/$b.oref" "$T/$b.ref" || { echo "RED $b: committed ref disagrees with the live oracle"; red=$((red+1)); continue; }
  timeout -k 5 20 ./scrip "$f" </dev/null >"$T/$b.m3" 2>/dev/null
  cmp -s "$T/$b.m3" "$T/$b.ref" || { echo "RED m3 $b"; red=$((red+1)); }
  if timeout -k 5 60 ./scrip --compile --out="$T/$b.s" "$f" </dev/null >/dev/null 2>&1 && gcc -no-pie "$T/$b.s" -o "$T/$b.bin" -L./out -lscrip_rt -lm -Wl,-rpath,"$PWD/out" >/dev/null 2>&1; then
    timeout -k 5 20 "$T/$b.bin" </dev/null >"$T/$b.m4" 2>/dev/null
    cmp -s "$T/$b.m4" "$T/$b.ref" || { echo "RED m4 $b"; red=$((red+1)); }
  else echo "RED m4 $b: compile or link failed"; red=$((red+1)); fi
done
echo "DCAP_REPL witnesses=$n red=$red"
[ "$red" -eq 0 ] && { echo "GREEN: deferred-replacement witnesses match the oracle in both modes (witnesses=$n)"; exit 0; }
echo "RED: deferred-replacement witnesses diverge (red=$red of $n x 2 modes)"; exit 1
