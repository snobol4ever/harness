#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_triangulate_rebus.sh -- Rebus benchmark board (row readme-perf-grids-three-angles-all-seven,
# I26). ⛔ WHY THIS DIFFERS FROM THE OTHER TRIANGULATORS: Rebus has NO independent rival implementation
# to compare against (README § Rebus: "no independent implementation to borrow a suite from") -- unlike
# Snocone, which shares SNOBOL4's engine closely enough that "the SNOBOL4 twin" is a fair, apples-to-apples
# rival, Rebus is Icon-lineage (Griswold TR 84-9) with no production implementation at all. Fabricating a
# "× vs X" ratio with no X would be exactly the unit-mismatch class RULES.md § THE INSTRUMENT LAWS warns
# against (a correction/comparison that does not show what it is commensurable with is not one) -- so this
# board reports SCRIP's own m3/m4 instruction counts, never a synthesized external multiple.
#
# METHOD: callgrind Ir per kernel (valgrind --tool=callgrind), NOT wall-clock -- per hq_P's live-load
# ruling this session (box at 20-30 load, 16-seat fleet running; wall-clock numbers taken now are noise,
# callgrind is contention-immune). m4 Ir is pure execution (prebuilt binary); m3 Ir is a WHOLE-PROCESS
# total that includes SCRIP's own in-process compile-to-slab step, same caveat the Icon demo grid already
# states (README § Icon, "m3 compiles at run time, so its total includes the compile") -- so m3 and m4
# are never presented as if they measure the same thing, and no m3-vs-m4 multiple is published either
# (that WOULD be commensurable, but "faster because it skipped compiling" is not the question this board
# asks; a future clock-hook inside the JIT path could split it, not done here).
#
# EXIT: 0 = every kernel measured. 2 = REFUSED -- missing scrip/valgrind/corpus, loud, never a fabricated row.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP_BIN="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="$HERE/../../SCRIP/out"
KDIR="$S4E/corpus/benchmarks/rebus"
KERNELS="${KERNELS:-fib_recur arith_loop string_concat}"

if [ ! -x "$SCRIP_BIN" ]; then echo "⛔ REFUSED (rc=2): scrip not built at $SCRIP_BIN"; exit 2; fi
if ! command -v valgrind >/dev/null 2>&1; then echo "⛔ REFUSED (rc=2): valgrind not on PATH -- callgrind Ir is this board's whole method"; exit 2; fi
if [ ! -d "$KDIR" ]; then echo "⛔ REFUSED (rc=2): no kernel dir at $KDIR"; exit 2; fi

# ⛔⭐ THE Ir READING GOES THROUGH lib_ir_measure.sh AND NOWHERE ELSE.  This script used to run callgrind
# here with NO exit-status check, so a kernel that SEGVed or error-exited published the instruction count of
# its dying path as an ordinary cell.  callgrind counts whatever the client does; only the exit status knows
# whether the work happened.  The lib is the ONE place that rule lives, for every Ir cell in the tree.
. "$HERE/lib_ir_measure.sh" 2>/dev/null || { echo "⛔ REFUSED (rc=2): cannot load lib_ir_measure.sh -- this board will not read Ir by hand"; exit 2; }
# each kernel runs at the heap and stack its .heap and .stack sidecars declare, -d<kb>k -s<kb>k after --run in mode 3 and leading the
# binary's arguments in mode 4 (ceo CEO-1353, RULES.md clause 8 (g); the coo 2026-10-03: both arms ran every kernel at the shipped size)
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED (rc=2): cannot load lib_declared_arena.sh -- the one reader of a declared heap and stack"; exit 2; }

echo "REBUS_TRIANGULATE -- callgrind Ir, RT_OPT=-O0, tree $(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null || echo '?')"
echo "kernel               m3_Ir(compile+run)   m4_Ir(run only)"
SCRIP_HASH="$(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null || echo unknown)"
N=0; RED=0
for k in $KERNELS; do
  f="$KDIR/$k.reb"
  if [ ! -f "$f" ]; then echo "⛔ REFUSED (rc=2): kernel missing: $f"; exit 2; fi
  sw="$(declared_switches_beside "$f")" || { echo "⛔ REFUSED (rc=2): $k: a .heap or .stack sidecar the reader refuses (it said why above)"; exit 2; }
  # valgrind fixes the client's main stack at start (--main-stacksize, default the shell's ulimit -s) and mode 3's -s grows the main
  # stack in place, so the declared stack reaches valgrind too or mode 3 dies "can't grow stack" at 8 MB (the coo 2026-10-03, measured:
  # a 50000-deep Rebus recursion at -s262144k reads rc 139 under callgrind without the flag, depth=50000 with it). The declared stack
  # PLUS 1 MB, no more: valgrind's own frames sit on the client stack (a 30000-entry table that runs natively at -s4096k tripped SCRIP's
  # overflow handler at exactly 4 MB and ran at 5), and mode 3's limit IS this size under valgrind, so more headroom grades a different
  # program (at +8 MB a recursion that overflows its declared 4 MB natively ran to its answer).
  skb="$(declared_stack_kb_beside "$f")" || { echo "⛔ REFUSED (rc=2): $k: a .stack sidecar the reader refuses"; exit 2; }
  vgs="${IR_VG_FLAGS:-}"; [ -n "$skb" ] && vgs="$vgs --main-stacksize=$(( (skb + 1024) * 1024 ))"
  m3ir="$(IR_VG_FLAGS="$vgs" ir_measure "$SCRIP_BIN" --run $sw "$f" < /dev/null)"
  s="$(mktemp -d)"
  "$SCRIP_BIN" --compile "$f" -o "$s/p.s" < /dev/null 2>/dev/null || { echo "⛔ REFUSED (rc=2): $k failed to compile mode-4"; exit 2; }
  gcc "$s/p.s" -o "$s/p.bin" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" 2>/dev/null || { echo "⛔ REFUSED (rc=2): $k failed to link mode-4"; exit 2; }
  m4ir="$(IR_VG_FLAGS="$vgs" ir_measure "$s/p.bin" $sw < /dev/null)"
  rm -rf "$s"
  for v in "$m3ir" "$m4ir"; do r="$(ir_reason "$v")"; [ -z "$r" ] || { echo "⚠ $k: $(ir_cell "$v") -- $r" >&2; RED=$((RED+1)); }; done
  printf '%-20s %18s %18s\n' "$k" "$(ir_cell "$m3ir")" "$(ir_cell "$m4ir")"
  N=$((N+1))
done
echo "REBUS_BOARD kernels=$N voided_arms=$RED (no external rival exists; see this script's own header)"
[ "$N" -gt 0 ] && [ "$RED" -eq 0 ]
