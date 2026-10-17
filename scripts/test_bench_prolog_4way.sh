#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
# test_bench_prolog_4way.sh — 4-way Prolog benchmark comparison.
# Columns: GNU (gprolog) · SWI (swipl) · m3 (scrip --run, in-process x86 binary)
#          · m4 (scrip --compile x86 -> as+gcc -> exec).
# Each program has a <name>.ref signature (the corpus benchmark convention).
# A cell is PASS iff that engine's stdout equals .ref, else FAIL/FENCE/etc.
# CONSENSUS = all four agree with .ref. The .ref file is itself derived
# from a real Prolog, so PASS means "matches the reference observable semantics."
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
HAVE_GNU=0; gprolog_bin >/dev/null 2>&1 && HAVE_GNU=1
HAVE_SWI=0; command -v swipl   >/dev/null 2>&1 && HAVE_SWI=1
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf "%-14s %-7s %-7s %-7s %-7s  %s\n" BENCH GNU SWI m3 m4 "consensus / result"
consensus=0; divergent=0; tot=0
for pl in "$B"/*.pl; do
  s=$(basename "${pl%.pl}"); exp="${pl%.pl}.ref"; tot=$((tot+1))
  [ -f "$exp" ] || { printf "%-14s %-7s\n" "$s" "NO-REF"; continue; }
  want=$(cat "$exp")
  DECL_SW=(); dw=$(declared_switches_beside "$pl") || { echo "⛔ REFUSED-TO-GRADE: $s: a .stack or .heap sidecar the reader refuses (it said why above)"; exit 2; }
  [ -n "$dw" ] && read -r -a DECL_SW <<<"$dw"; undeclared_beside_named "$pl" || true
  # --- GNU Prolog (gprolog): consult fires :- initialization(main), then halt. ---
  gnu="-"
  if [ "$HAVE_GNU" = 1 ]; then
    go=$(cd "$W" && timeout -k 5 "$T" "$(gprolog_bin)" --consult-file "$pl" --query-goal halt 2>/dev/null </dev/null \
         | gprolog_output_filter)
    [ "$go" = "$want" ] && gnu=PASS || gnu=FAIL
  fi
  # --- SWI-Prolog (swipl): load file (runs initialization/1), then halt. ---
  swi="-"
  if [ "$HAVE_SWI" = 1 ]; then
    so=$(cd "$W" && timeout -k 5 "$T" swipl -q -g halt "$pl" 2>/dev/null </dev/null | head -200)
    [ "$so" = "$want" ] && swi=PASS || swi=FAIL
  fi
  # --- SCRIP mode 3 (--run): emit BINARY into RX slab, run in-process. ---
  m3out=$(cd "$W" && timeout -k 5 "$T" "$SCRIP" --run "${DECL_SW[@]}" "$pl" </dev/null 2>"$W/$s.m3err" | head -200)
  if grep -q 'PL-GZ FENCE' "$W/$s.m3err" 2>/dev/null || echo "$m3out" | grep -q 'PL-GZ FENCE'; then m3=FENCE
  elif [ "$m3out" = "$want" ]; then m3=PASS; else m3=FAIL; fi
  # --- SCRIP mode 4 (--compile x86): emit TEXT asm -> as + gcc -> exec. ---
  m4=SKIP
  asm=$(cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile --target=x86 "$pl" </dev/null 2>"$W/$s.m4err")
  if echo "$asm" | grep -qE '^\s*\.(intel_syntax|text|globl)'; then
    printf '%s\n' "$asm" > "$W/$s.s"
    if (cd "$W" && as --64 -o "$s.o" "$s.s" 2>"$W/$s.aserr") \
       && gcc -no-pie -o "$W/$s.bin" "$W/$s.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>"$W/$s.lderr"; then
      m4out=$(cd "$W" && timeout -k 5 "$T" ./$s.bin "${DECL_SW[@]}" </dev/null 2>/dev/null | head -200)
      [ "$m4out" = "$want" ] && m4=PASS || m4=FAIL
    else m4=BUILD; fi
  elif grep -q 'PL-GZ FENCE' "$W/$s.m4err" 2>/dev/null; then m4=FENCE; else m4=NOEMIT; fi
  # --- consensus: every AVAILABLE engine PASS ---
  allpass=1
  [ "$HAVE_GNU" = 1 ] && [ "$gnu" != PASS ] && allpass=0
  [ "$HAVE_SWI" = 1 ] && [ "$swi" != PASS ] && allpass=0
  [ "$m3" != PASS ] && allpass=0
  [ "$m4" != PASS ] && allpass=0
  if [ "$allpass" = 1 ]; then consensus=$((consensus+1)); verdict="CONSENSUS"; else divergent=$((divergent+1)); verdict="DIVERGENT"; fi
  printf "%-14s %-7s %-7s %-7s %-7s  %s %s\n" "$s" "$gnu" "$swi" "$m3" "$m4" "$verdict" "$(echo "$m3out" | head -1 | cut -c1-30)"
done
echo
echo "ENGINES: GNU=$( [ $HAVE_GNU = 1 ] && "$(gprolog_bin)" --version </dev/null 2>&1 | head -1 || echo absent )"
echo "         SWI=$( [ $HAVE_SWI = 1 ] && swipl --version </dev/null 2>&1 | head -1 || echo absent )"
echo "RESULT: consensus(all-4-agree)=$consensus  divergent=$divergent  total=$tot"
[ "$divergent" -eq 0 ]
