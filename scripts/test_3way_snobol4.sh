#!/usr/bin/env bash
# 3-way SNOBOL4 comparison: SCRIP mode-4 (AOT native) vs SPITBOL oracle vs CSNOBOL4.
# Correctness = the "result:" line must agree across all three present engines.
# Performance = wall-clock ms, ratio = SCRIP/SPITBOL. The program-internal "ms:" line
# is captured for reference but TIME() semantics differ across engines, so the RATIO
# is computed from wall-clock (date +%s.%N around the run), which is engine-neutral.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/snobol4}"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
SBL="${SBL:-$(sbl_clean_bin)}"; CSNO="${CSNO:-$(command -v snobol4)}"   # BENCHMARK oracle (s255)
T="${TIMEOUT:-120}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE libscrip_rt.so not built"; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSED-TO-GRADE bench corpus missing"; exit 2; }
have_sbl=0; [ -x "$SBL" ] && have_sbl=1
have_csno=0; [ -n "$CSNO" ] && [ -x "$CSNO" ] && have_csno=1
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
res_of(){ grep -i 'result:' "$1" 2>/dev/null | head -1 | sed 's/^[^:]*: *//'; }
selfms_of(){ grep -i 'ms:' "$1" 2>/dev/null | head -1 | sed 's/^[^:]*: *//'; }
run_wall(){ local out="$1"; shift; local t0 t1; t0=$(date +%s.%N)
  ( timeout -k 5 "$T" "$@" </dev/null >"$out" 2>/dev/null ); local rc=$?
  t1=$(date +%s.%N); WALL=$(awk "BEGIN{printf \"%.0f\",($t1-$t0)*1000}"); return $rc; }
printf "%-22s | %-10s %8s | %-10s %8s | %-10s %8s | %7s %s\n" \
  BENCH SCRIP-res SCRIP-wal SBL-res SBL-wall CSNO-res CSNO-wall "S/SBL" CORRECT
ok=0; bad=0
for sno in "$B"/*.sno; do
  s=$(basename "${sno%.sno}")
  "$SCRIP" --compile "$sno" > "$W/$s.s" 2>/dev/null
  sc_res="-"; sc_ms="-"; sc_wall="-"
  if [ -s "$W/$s.s" ] && gcc -no-pie "$W/$s.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/$s.prog" 2>/dev/null; then
    run_wall "$W/$s.sc" "$W/$s.prog"; sc_wall=$WALL
    sc_res=$(res_of "$W/$s.sc"); sc_ms=$(selfms_of "$W/$s.sc")
  fi
  sb_res="-"; sb_ms="-"; sb_wall="-"
  if [ $have_sbl -eq 1 ]; then run_wall "$W/$s.sb" "$SBL" $(sbl_lang_flags) "$sno"; sb_wall=$WALL
    sb_res=$(res_of "$W/$s.sb"); sb_ms=$(selfms_of "$W/$s.sb"); fi
  cs_res="-"; cs_ms="-"; cs_wall="-"
  if [ $have_csno -eq 1 ]; then run_wall "$W/$s.cs" "$CSNO" "$sno"; cs_wall=$WALL
    cs_res=$(res_of "$W/$s.cs"); cs_ms=$(selfms_of "$W/$s.cs"); fi
  ratio="-"
  if [ "$sc_wall" != "-" ] && [ "$sb_wall" != "-" ] && [ "$sb_wall" -gt 0 ] 2>/dev/null; then
    ratio=$(awk "BEGIN{printf \"%.2f\",$sc_wall/$sb_wall}")x; fi
  correct="?"
  if [ -n "$sc_res" ] && [ "$sc_res" != "-" ] && [ -n "$sb_res" ] && [ "$sb_res" != "-" ]; then
    if [ "$sc_res" = "$sb_res" ] && { [ $have_csno -eq 0 ] || [ -z "$cs_res" ] || [ "$cs_res" = "-" ] || [ "$cs_res" = "$sc_res" ]; }; then
      correct="MATCH"; ok=$((ok+1)); else correct="DIVERGE"; bad=$((bad+1)); fi
  fi
  printf "%-22s | %-10.10s %8s | %-10.10s %8s | %-10.10s %8s | %7s %s\n" \
    "$s" "${sc_res:--}" "${sc_wall}" "${sb_res:--}" "${sb_wall}" "${cs_res:--}" "${cs_wall:--}" "$ratio" "$correct"
done
echo
echo "engines: SCRIP=yes SPITBOL=$([ $have_sbl -eq 1 ] && echo yes || echo NO) CSNOBOL4=$([ $have_csno -eq 1 ] && echo yes || echo NO)"
echo "correctness: MATCH=$ok DIVERGE=$bad   (ratio col = SCRIP_wall / SPITBOL_wall; <1.0 = SCRIP faster)"
