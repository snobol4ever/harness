#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/snobol4}"; CAP=200000; T="${TIMEOUT:-30}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE libscrip_rt.so not built"; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSED-TO-GRADE bench corpus missing"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf "%-22s %-9s %10s  %s\n" BENCH STATUS "wall(ms)" "self/ref"
ok=0; crash=0; fail=0
for sno in "$B"/*.sno; do
  s=$(basename "${sno%.sno}"); ref="${sno%.sno}.ref"
  "$SCRIP" --compile "$sno" > "$W/$s.s" 2>/dev/null
  if [ ! -s "$W/$s.s" ] || ! gcc -no-pie "$W/$s.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/$s.prog" 2>/dev/null; then
    printf "%-22s %-9s %10s  %s\n" "$s" BUILD-ERR - -; crash=$((crash+1)); continue; fi
  t0=$(date +%s.%N); ( cd "$W" && timeout -k 5 "$T" ./$s.prog </dev/null >"$s.out" 2>"$s.err" ); rc=$?; t1=$(date +%s.%N)
  wall=$(awk "BEGIN{printf \"%.1f\",($t1-$t0)*1000}"); head -c $CAP "$W/$s.out" >"$W/$s.cap"; mv "$W/$s.cap" "$W/$s.out"
  note=$(grep -i 'ms:' "$W/$s.out" | head -1); [ -z "$note" ] && note="(no ms)"
  if grep -q BOMB "$W/$s.err" 2>/dev/null; then st=CRASH; note=$(grep -o 'BOMB.*' "$W/$s.err"|head -1|cut -c1-46)
  elif [ $rc -ne 0 ] || [ ! -s "$W/$s.out" ]; then st=CRASH
  elif [ -f "$ref" ] && ! diff -q <(grep -vi 'ms:' "$W/$s.out") <(grep -vi 'ms:' "$ref") >/dev/null 2>&1; then st=FAIL; fail=$((fail+1))
  else st=OK; ok=$((ok+1)); fi
  [ "$st" = CRASH ] && crash=$((crash+1))
  printf "%-22s %-9s %10s  %s\n" "$s" "$st" "$wall" "$note"
done
echo; echo "REAL RESULT: OK=$ok FAIL=$fail CRASH=$crash (of $((ok+fail+crash)))"
[ "$crash" -eq 0 ] && [ "$fail" -eq 0 ]
