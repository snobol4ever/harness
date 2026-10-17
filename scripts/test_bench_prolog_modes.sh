#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/prolog/bench}"; T="${TIMEOUT:-30}"
# THE SCRIP ARMS RUN AT EACH KERNEL'S DECLARED HEAP AND STACK (<k>.heap / <k>.stack, read by lib_declared_arena.sh and carried as
#   -d<kb>k -s<kb>k after --run and at the head of the mode-4 binary's argv; RULES.md clause 8 (g), CEO-1353). The script typed
#   ulimit -s unlimited here until 2026-10-01 and passed nothing: SCRIP sets its own stack from -s, so tak (declared 65536 KB) read
#   FAIL in m3 and m4 at the 4 MB default. MEASURED 2026-10-01 at c1c899df3: all 23 kernels read the same on gprolog, swipl, m3 and m4
#   at the shell's soft 8 MB stack and at unlimited, so the ulimit did nothing for any engine.
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot load lib_declared_arena.sh -- the ONE reader of a program's declared stack and heap sidecars (CEO-1281)"; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE libscrip_rt.so not built"; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSED-TO-GRADE bench corpus missing: $B"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf "%-16s %-8s %-8s %-8s  %s\n" BENCH m3 m4 ORACLE "result/status"
ok=0; fence=0; fail=0; tot=0
for pl in "$B"/*.pl; do
  s=$(basename "${pl%.pl}"); exp="${pl%.pl}.ref"; tot=$((tot+1))
  [ -f "$exp" ] || { printf "%-16s %-8s\n" "$s" "NO-REF"; continue; }
  want=$(cat "$exp")
  DECL_SW=(); dw=$(declared_switches_beside "$pl") || { echo "⛔ REFUSED-TO-GRADE: $s: a .stack or .heap sidecar the reader refuses (it said why above)"; exit 2; }
  [ -n "$dw" ] && read -r -a DECL_SW <<<"$dw"; undeclared_beside_named "$pl" || true
  # mode 3 (--run): EMIT BINARY -> RX slab, in-process.
  m3out=$(cd "$W" && timeout -k 5 "$T" "$SCRIP" --run "${DECL_SW[@]}" "$pl" </dev/null 2>"$W/$s.m3err" | head -50)
  if grep -q 'PL-GZ FENCE' "$W/$s.m3err" 2>/dev/null || echo "$m3out" | grep -q 'PL-GZ FENCE'; then m3=FENCE
  elif [ "$m3out" = "$want" ]; then m3=PASS; else m3=FAIL; fi
  # mode 4 (--compile x86): EMIT TEXT -> as+gcc -> exec, separate process.
  m4=SKIP
  asm=$(cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile --target=x86 "$pl" </dev/null 2>"$W/$s.m4err")
  if echo "$asm" | grep -qE '^\s*\.(intel_syntax|text|globl)'; then
    printf '%s\n' "$asm" > "$W/$s.s"
    if (cd "$W" && as --64 -o "$s.o" "$s.s" 2>"$W/$s.aserr") \
       && gcc -no-pie -o "$W/$s.bin" "$W/$s.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>"$W/$s.lderr"; then
      m4out=$(cd "$W" && timeout -k 5 "$T" ./$s.bin "${DECL_SW[@]}" </dev/null 2>/dev/null | head -50)
      if [ "$m4out" = "$want" ]; then m4=PASS; else m4=FAIL; fi
    else m4=BUILD; fi
  elif grep -q 'PL-GZ FENCE' "$W/$s.m4err" 2>/dev/null; then m4=FENCE; else m4=NOEMIT; fi
  # oracle cross-check (informational): does a real prolog agree with .ref?
  orc="-"
  if gprolog_bin >/dev/null 2>&1; then
    go=$(timeout -k 5 "$T" "$(gprolog_bin)" --consult-file "$pl" --query-goal halt 2>/dev/null </dev/null \
         | gprolog_output_filter)
    [ "$go" = "$want" ] && orc=ok || orc=DIFF
  fi
  status="$m3out"; [ "$m3" = FENCE ] && status="(pl_gz_admit fence)"
  [ "$m3" = PASS ] && [ "$m4" = PASS ] && ok=$((ok+1))
  { [ "$m3" = FENCE ] || [ "$m4" = FENCE ] || [ "$m4" = NOEMIT ]; } && fence=$((fence+1))
  { [ "$m3" = FAIL ] || [ "$m4" = FAIL ] || [ "$m4" = BUILD ]; } && fail=$((fail+1))
  printf "%-16s %-8s %-8s %-8s  %s\n" "$s" "$m3" "$m4" "$orc" "$(echo "$status" | cut -c1-44)"
done
echo; echo "RESULT: green(m3&m4)=$ok  frontier(fenced)=$fence  broken=$fail  total=$tot"
[ "$fail" -eq 0 ]
