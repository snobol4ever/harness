#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_triangulate_snocone.sh -- Snocone benchmark board vs its SNOBOL4 twin (row
# readme-perf-grids-three-angles-all-seven, I26). Snocone compiles into the same engine as SNOBOL4
# (README § Snocone), so "the SNOBOL4 twin" -- the identical kernel hand-translated into SNOBOL4 syntax,
# both graded against the same output -- is the fair rival here, per this task's own GOAL text.
#
# METHOD: callgrind Ir per kernel (valgrind --tool=callgrind against SCRIP m4 and against the CLEAN
# SPITBOL benchmark oracle), NOT wall-clock -- per hq_P's live-load ruling this session (box at 20-30
# load, 16-seat fleet running; wall-clock is noise right now, callgrind is contention-immune). Multiple =
# SPITBOL_Ir / SCRIP_Ir (reference/ours, the FASTER axis -- RULES.md § THE TWO-NUMBER BENCHMARK BASIS's
# unit rule; above 1.00x SCRIP is faster). m3 Ir is reported separately, never folded into the m4-vs-SPITBOL
# multiple, because m3's total includes SCRIP's own in-process compile (same caveat as the Icon demo grid).
# ⛔ ORACLE: the CLEAN benchmark oracle only (lib_oracle_flags.sh:sbl_clean_bin(), -bf) -- never
# x64/bin/sbl, whose monitor-IPC bridge costs ~2.2-3.5x Ir and would misreport every number here.
#
# EXIT: 0 = every kernel measured on both engines. 2 = REFUSED -- missing scrip/valgrind/oracle/corpus.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP_BIN="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="$HERE/../../SCRIP/out"
SC_DIR="$S4E/corpus/benchmarks/snocone"
SNO_DIR="$S4E/corpus/benchmarks/snobol4"
# kernel:twin-sno-basename pairs -- string_concat's SNOBOL4 twin is named _twin to avoid colliding
# with the pre-existing string_concat.sno kernel (a different, unrelated benchmark).
KERNELS="${KERNELS:-fib_recur:fib_recur arith_loop:arith_loop_twin string_concat:string_concat_twin}"

if [ ! -x "$SCRIP_BIN" ]; then echo "⛔ REFUSED (rc=2): scrip not built at $SCRIP_BIN"; exit 2; fi
if ! command -v valgrind >/dev/null 2>&1; then echo "⛔ REFUSED (rc=2): valgrind not on PATH"; exit 2; fi
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED (rc=2): lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_clean_bin)"
[ -x "$SBL" ] || { echo "⛔ REFUSED (rc=2): clean SPITBOL oracle absent: $SBL"; exit 2; }
SBL_FLAGS="$(sbl_lang_flags)"

# ⛔⭐ THE Ir READING GOES THROUGH lib_ir_measure.sh AND NOWHERE ELSE.  This script used to run callgrind
# here and pipe callgrind_annotate straight into awk with NO exit-status check, so a kernel that SEGVed or
# error-exited published the instruction count of its dying path as an ordinary cell -- and then this board
# divided by it.  A crash that announces itself as a number is worse than one that announces itself as a
# hole; the lib is the ONE place that rule lives, for every Ir cell in the tree.  A caller that cannot load
# it REFUSES rather than re-deriving a private extraction (same law as lib_perf_fmt.sh / lib_oracle_flags.sh).
. "$HERE/lib_ir_measure.sh" 2>/dev/null || { echo "⛔ REFUSED (rc=2): cannot load lib_ir_measure.sh -- this board will not read Ir by hand"; exit 2; }
# each Snocone kernel runs at its declared heap and stack (-d/-s after --run in mode 3, leading the binary's arguments in mode 4) and the
# SPITBOL twin at the sizes its .oracle_args declares (ceo CEO-1353, RULES.md clause 8 (g); the coo 2026-10-03: all three arms ran bare)
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED (rc=2): cannot load lib_declared_arena.sh -- the one reader of a declared heap and stack"; exit 2; }

echo "SNOCONE_TRIANGULATE -- callgrind Ir vs SPITBOL (clean oracle $SBL_FLAGS), RT_OPT=-O0, tree $(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null || echo '?')"
echo "kernel               m3_Ir(compile+run)   m4_Ir(run only)      SPITBOL_Ir      × (m4 vs SPITBOL)"
N=0; RED=0
for pair in $KERNELS; do
  k="${pair%%:*}"; twin="${pair##*:}"
  scf="$SC_DIR/$k.sc"; snf="$SNO_DIR/$twin.sno"
  [ -f "$scf" ] || { echo "⛔ REFUSED (rc=2): kernel missing: $scf"; exit 2; }
  [ -f "$snf" ] || { echo "⛔ REFUSED (rc=2): twin missing: $snf"; exit 2; }
  sw="$(declared_switches_beside "$scf")" || { echo "⛔ REFUSED (rc=2): $k: a .heap or .stack sidecar the reader refuses (it said why above)"; exit 2; }
  oa="$(declared_oracle_args_beside "$snf")" || { echo "⛔ REFUSED (rc=2): $twin: a .oracle_args sidecar the reader refuses (it said why above)"; exit 2; }
  # valgrind fixes the client's main stack at start (--main-stacksize, default the shell's ulimit -s) and mode 3's -s grows the main
  # stack in place, so the declared stack reaches valgrind too or mode 3 dies "can't grow stack" at 8 MB (the coo 2026-10-03, measured:
  # a 50000-deep Rebus recursion at -s262144k reads rc 139 under callgrind without the flag, depth=50000 with it). The declared stack
  # PLUS 1 MB, no more: valgrind's own frames sit on the client stack (a 30000-entry table that runs natively at -s4096k tripped SCRIP's
  # overflow handler at exactly 4 MB and ran at 5), and mode 3's limit IS this size under valgrind, so more headroom grades a different
  # program (at +8 MB a recursion that overflows its declared 4 MB natively ran to its answer).
  skb="$(declared_stack_kb_beside "$scf")" || { echo "⛔ REFUSED (rc=2): $k: a .stack sidecar the reader refuses"; exit 2; }
  vgs="${IR_VG_FLAGS:-}"; [ -n "$skb" ] && vgs="$vgs --main-stacksize=$(( (skb + 1024) * 1024 ))"
  m3ir="$(IR_VG_FLAGS="$vgs" ir_measure "$SCRIP_BIN" --run $sw "$scf" < /dev/null)"
  s="$(mktemp -d)"
  "$SCRIP_BIN" --compile "$scf" --out="$s/p.s" < /dev/null 2>/dev/null || { echo "⛔ REFUSED (rc=2): $k failed to compile mode-4"; exit 2; }
  gcc "$s/p.s" -o "$s/p.bin" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" 2>/dev/null || { echo "⛔ REFUSED (rc=2): $k failed to link mode-4"; exit 2; }
  m4ir="$(IR_VG_FLAGS="$vgs" ir_measure "$s/p.bin" $sw < /dev/null)"
  rm -rf "$s"
  sblir="$(ir_measure "$SBL" $SBL_FLAGS $oa "$snf" < /dev/null)"
  # ⛔ THE MULTIPLE IS COMPUTED ONLY FROM TWO READINGS THAT ARE ACTUALLY READINGS.  A voided cell must
  # never reach the arithmetic -- a ratio built on a crashed arm is the crash wearing the board's format.
  for v in "$m3ir" "$m4ir" "$sblir"; do r="$(ir_reason "$v")"; [ -z "$r" ] || echo "⚠ $k: $(ir_cell "$v") -- $r" >&2; done
  if ir_is_number "$sblir" && ir_is_number "$m4ir"; then mult="$(awk -v r="$sblir" -v o="$m4ir" 'BEGIN{ if (o+0==0) print "n/a"; else printf "%.3fx", r/o }')"
  else mult="n/a (an arm was not measured)"; RED=$((RED+1)); fi
  printf '%-20s %18s %18s %18s   %s\n' "$k" "$(ir_cell "$m3ir")" "$(ir_cell "$m4ir")" "$(ir_cell "$sblir")" "$mult"
  N=$((N+1))
done
echo "SNOCONE_BOARD kernels=$N voided_arms=$RED"
[ "$N" -gt 0 ] && [ "$RED" -eq 0 ]
