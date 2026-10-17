#!/usr/bin/env bash
# Three-way SNOBOL4 benchmark comparison: SCRIP mode-4 (AOT native) vs SPITBOL vs CSNOBOL4.
# Writes a TSV row per benchmark to $OUT as it goes (partial progress survives a timeout).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
ROOT=$S4E/SCRIP
B=$S4E/corpus/benchmarks/snobol4
. "$(dirname "${BASH_SOURCE[0]}")/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
SBL="${SBL:-$(sbl_clean_bin)}"   # BENCHMARK oracle (s255) -- x64/bin/sbl is instrumented, ~2.2-3.5x slower (was a bare non-overridable assignment; row oracle-two-face-adoption normalized it to the same ${SBL:-...} pattern every other converted script uses)
[ -x "$SBL" ] || { echo "⛔ ORACLE ABSENT: $SBL — every sbl_ms/sbl_rc column below would be fiction, not a benign gap. The 'done' progress line has no rc visible -- a missing oracle must not print a plausible sbl=NNNms. Build /home/resources/spitbol-bench-oracle (see RULES.md Oracles) -- seats do not clone x64 (s255)." >&2; exit 3; }
CSN=$S4A/csnobol4/snobol4
RT=$ROOT/out
OUT=${OUT:-/tmp/cmp3.tsv}
T=${T:-90}
cd "$ROOT"
# light -> heavy; the list is the CORPUS, not a typed set: nine legacy variants were retired s170
# (BM-2 "enough variations"), so a typed order would silently drop rows as the family changes.
ORDER="${ORDER:-$(ls "$B"/*.sno 2>/dev/null | xargs -r -n1 basename | sed 's/\.sno$//' | tr '\n' ' ')}"
wall() { awk "BEGIN{printf \"%.0f\",($2-$1)*1000}"; }
selfms() { grep -i '^ms:' "$1" 2>/dev/null | grep -o '[0-9]\+' | head -1; }
sans() { grep -vi '^ms:' "$1" 2>/dev/null; }
run() { local t0 t1; t0=$(date +%s.%N); timeout -k 5 "$T" "$@" </dev/null >"$CO" 2>"$CE"; RC=$?; t1=$(date +%s.%N); WALL=$(wall "$t0" "$t1"); }
printf "bench\tagree\tscrip_ms\tsbl_ms\tcsn_ms\tscrip_self\tsbl_self\tcsn_self\tscrip_rc\tsbl_rc\tcsn_rc\toutput\n" > "$OUT"
for s in $ORDER; do
  CO=/tmp/_c3.$s.o; CE=/tmp/_c3.$s.e
  # --- SCRIP mode-4: compile once, run the native binary ---
  ./scrip --compile "$B/$s.sno" >/tmp/_c3.$s.s 2>/dev/null
  if [ -s /tmp/_c3.$s.s ] && gcc -no-pie -x assembler /tmp/_c3.$s.s -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o /tmp/_c3.$s.bin 2>/dev/null; then
    run /tmp/_c3.$s.bin; SCW=$WALL; SCR=$RC; SCS=$(selfms "$CO"); sans "$CO" >/tmp/_c3.$s.scrip
  else
    SCW=- ; SCR=BUILDERR; SCS=- ; : >/tmp/_c3.$s.scrip
  fi
  # --- SPITBOL (sbl -bf, s189 authority): plain -b manufactures phantom duplicate labels under folding ---
  run "$SBL" $(sbl_lang_flags) "$B/$s.sno"; SBW=$WALL; SBR=$RC; SBS=$(selfms "$CO"); sans "$CO" >/tmp/_c3.$s.sbl
  # --- CSNOBOL4 ---
  run "$CSN" "$B/$s.sno"; CNW=$WALL; CNR=$RC; CNS=$(selfms "$CO"); sans "$CO" >/tmp/_c3.$s.csn
  # --- agreement (sans ms line); SCRIP is reference ---
  AG=AGREE
  if ! diff -q /tmp/_c3.$s.scrip /tmp/_c3.$s.sbl >/dev/null 2>&1; then AG=DIFF; fi
  if ! diff -q /tmp/_c3.$s.scrip /tmp/_c3.$s.csn >/dev/null 2>&1; then AG=DIFF; fi
  OUTSUM=$(head -1 /tmp/_c3.$s.scrip | cut -c1-46)
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$s" "$AG" "$SCW" "$SBW" "$CNW" "${SCS:-?}" "${SBS:-?}" "${CNS:-?}" "$SCR" "$SBR" "$CNR" "$OUTSUM" >> "$OUT"
  echo "done $s: agree=$AG scrip=${SCW}ms sbl=${SBW}ms csn=${CNW}ms"
done
