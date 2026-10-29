#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# test_bench_raku_timed.sh -- ANGLE 1 of the Raku three-angle triangulation (row
# bench-grids-rebase-to-two-number-basis), mirroring test_bench_prolog_timed.sh per
# ARCH-BENCH-CAMPAIGN-README-TABLES.md § THREE-ANGLE TRIANGULATION.
#
# Fixed CPU-TIME budget, iterations counted: a live doubling search (N=1,4,16,...) picks the largest N
# whose loop-wrapped kernel completes within TIME_BUDGET_MS of CPU time, then reports iters/s = N / cpu_s.
# N is DERIVED FRESH every run (never read from a committed file) -- the independence property the
# cross-proof needs against angle 2 (bench_raku_fixed_iter.sh), which instead reads a pre-committed,
# historical N from corpus/benchmarks/raku/fixed-iter-n.tsv. Same atomic operation (loop N times, measure
# CPU time), different SOURCE for N -- live-derived here, historically-committed there.
#
# ⛔ RAKU KERNELS ARE TOP-LEVEL SCRIPTS, NOT CALLABLE SUBS (unlike Prolog's named predicates), so the
# derived twin cannot rename a predicate head the way mkwrap() does for Prolog. Instead it wraps exactly
# the region the kernel's OWN self-timing bracket already delimits -- RULES.md § THE TWO-NUMBER BENCHMARK
# BASIS requires every self-timed kernel to bracket the WORK between
#   my $t0 = wall_us(); my $m0 = wall_ms();      ...WORK...      my $t1 = wall_us(); my $m1 = wall_ms();
# -- so that bracket IS the loop body: wrap() inserts `for 1..N { ... }` around exactly the WORK lines.
# Setup before the bracket (class defs, etc.) and output/note after it run ONCE, exactly as the single-shot
# form -- only the WORK repeats, mirroring Prolog's between(1,N,_) driving bench__main N times.
#
# ⛔ CORRECTNESS GATES THE TIMING: this script re-verifies each kernel's SINGLE-SHOT (unwrapped, original
# file) stdout against corpus/benchmarks/raku/<k>.ref on m3, m4 AND rakudo -- byte-for-byte via `cmp`, never
# a `$()`-captured string compare (FINDING-2026-09-01-seat15: `.expected`/`.ref` files carry no trailing
# newline and `$()` silently strips one, which can paper over a real diff) -- before ever timing a kernel.
# A kernel that fails this on ANY engine is SKIPped, never silently timed anyway.
#
# ⛔⭐ THE exit= FIELD IS THE ONLY TRUSTED CRASH SIGNAL (bench_prolog_fixed_iter.sh's law, carried over
# verbatim): a segfaulting child still writes a well-formed BENCH_RUSAGE line -- grepping stderr TEXT for
# a crash message is not reliable. Every run here is gated on BENCH_RUSAGE's own exit= field, nothing else.
#
# ⛔ THE RAKUDO PRELUDE IS STAGED IN A SCRATCH DIR, NEVER LOADED WITH -I<corpus dir> (bench_triangulate_raku.sh's
# law, carried over): Rakudo precompiles a -M module into a .precomp/ beside it -- the corpus is never a
# Rakudo output directory.
#
# ⛔⭐ TIME_BUDGET_MS DEFAULTS TO 3000, NOT A SMALLER "PLENTY FOR A SUB-MS KERNEL" NUMBER -- MEASURED, NOT
# GUESSED (seat01 2026-09-02): a 300ms floor left this search stopping at a SMALL N for Rakudo specifically,
# and Rakudo/MoarVM's JIT has not warmed up by then -- direct measurement on string-escape showed ~3779us
# for a COLD single iteration vs ~149us/iteration once N reached the thousands (a >20x cold/warm gap on the
# exact same code). A search that stops cold reports a real number for the WRONG regime, and disagreed with
# angle 2's committed N (which happens to be large enough to be warm) by up to 2006x on first measurement --
# not a crash, not noise, a regime mismatch. Budget/NMAX raised so live search and committed N both land
# solidly in the warm regime for every currently self-timed kernel; point_class_add/add1 are unaffected (a
# single iteration alone already costs 20-30s of CPU time on m3, so the search's first check already clears
# any budget in this range and N stays 1 regardless).
# ⛔ NMAX IS CAPPED AT 32768, NOT LARGER -- MEASURED, NOT A ROUND NUMBER: string-escape looped past ~49152
# aborts BOTH m3 and m4 with "[WSI] workspace island exhausted (1024 MB, ... blocks) -- raise ZC_WSI_MB",
# a real SCRIP runtime ceiling (src/runtime/rt/gc_heap.{c,h}), not a wrap/harness bug -- confirmed the same
# wrapped source runs clean at N=32768 (rc=0) and aborts at N=65536 (rc=134) on both modes. Filed as
# FINDING-2026-09-02-seat01-raku-string-escape-loop-exhausts-1gb-workspace-island.md for the runtime/RTCC
# lane; out of scope to fix here. 32768 is comfortably under the observed threshold with margin.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
RDIR="${RAKU_DIR:-$S4E/corpus/benchmarks/raku}"
T="${TIMEOUT:-120}"; BUDGET_MS="${TIME_BUDGET_MS:-3000}"; NMAX="${NMAX:-32768}"
KERNELS="${KERNELS:-}"   # optional allowlist, same convention as bench_prolog_fixed_iter.sh
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_oracle_flags.sh -- the ONE authority for rival binaries." >&2; exit 2; }
. "$HERE/lib_raku_bench_wrap.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_raku_bench_wrap.sh -- the ONE authority for the loop-wrap transform." >&2; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE libscrip_rt.so not built"; exit 2; }
[ -d "$RDIR" ] || { echo "⛔ REFUSED-TO-GRADE raku bench corpus missing: $RDIR"; exit 2; }
[ -f "$RDIR/prelude_rakudo.rakumod" ] || { echo "⛔ REFUSED-TO-GRADE $RDIR/prelude_rakudo.rakumod missing"; exit 2; }
RAKU="$(rakudo_bin)" || exit 2
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot load lib_declared_arena.sh -- the ONE reader of a program's declared stack and heap sidecars (CEO-1283)"; exit 2; }
declare -a DECL_SW=()
WRAP="$ROOT/tools/bench_rusage"; [ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED: bench_rusage failed to build" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/prelude" && cp "$RDIR/prelude_rakudo.rakumod" "$W/prelude/" || { echo "⛔ REFUSED: cannot stage the prelude." >&2; exit 2; }

WORK_OPEN='$t0 = wall_us(); my $m0 = wall_ms();'

# one bench_rusage-wrapped run; echoes "cpu_us" or "- REASON" -- exit= is the ONLY signal trusted
run1() {
  local eng="$1" src="$2" rl xc user sys
  case "$eng" in
    m3)     "$WRAP" timeout -k 5 "$T" "$SCRIP" --run "${DECL_SW[@]}" "$src" </dev/null >/dev/null 2>"$W/e.$$" ;;
    m4)     local s="$W/$$.s" b="$W/$$.bin"
            if ! (cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile --out="$s" "$src" </dev/null >/dev/null 2>/dev/null) || [ ! -s "$s" ]; then echo "- BUILD-ERR"; return; fi
            if ! (as --64 -o "$W/$$.o" "$s" 2>/dev/null && gcc -no-pie -o "$b" "$W/$$.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null); then echo "- LINKFAIL"; return; fi
            "$WRAP" timeout -k 5 "$T" "$b" "${DECL_SW[@]}" </dev/null >/dev/null 2>"$W/e.$$" ;;
    rakudo) "$WRAP" timeout -k 5 "$T" "$RAKU" -I"$W/prelude" -Mprelude_rakudo "$src" </dev/null >/dev/null 2>"$W/e.$$" ;;
  esac
  rl=$(grep '^BENCH_RUSAGE:' "$W/e.$$" 2>/dev/null | tail -1)
  [ -n "$rl" ] || { echo "- DNF"; return; }
  xc=$(echo "$rl" | grep -oE 'exit=[0-9-]+' | cut -d= -f2)
  case "$xc" in ''|*[!0-9]*) echo "- CRASH(exit=${xc:-?})"; return ;; esac
  [ "$xc" -ge 128 ] && { echo "- CRASH(signal $((xc-128)))"; return; }
  [ "$xc" -ne 0 ] && { echo "- NONZERO($xc)"; return; }
  user=$(echo "$rl" | grep -oE 'user_us=[0-9]+' | cut -d= -f2); sys=$(echo "$rl" | grep -oE 'sys_us=[0-9]+' | cut -d= -f2)
  echo "$(( ${user:-0} + ${sys:-0} ))"
}
# doubling search: largest N whose cpu time >= BUDGET_MS, cap NMAX. Echoes "N rate" or "N -" + reason on the FIRST N that fails.
search() {
  local eng="$1" src="$2" N=1 cpu
  while :; do
    raku_bench_wrap "$src" "$N" "$W/s.raku"
    cpu=$(run1 "$eng" "$W/s.raku")
    case "$cpu" in
      -\ *) echo "$N $cpu"; return ;;   # first failure at this N -- report it, caller decides
    esac
    if [ "$cpu" -ge $((BUDGET_MS*1000)) ] || [ "$N" -ge "$NMAX" ]; then
      awk -v n="$N" -v us="$cpu" 'BEGIN{printf "%d %.4f", n, n/(us/1e6)}'; return
    fi
    N=$((N*4)); [ "$N" -gt "$NMAX" ] && N=$NMAX
  done
}

echo "TIME-BASED RAKU BENCHMARKS -- angle 1: fixed CPU-time budget (${BUDGET_MS}ms), iterations counted via live doubling search"
echo "engines: m3 m4 rakudo   corpus: $RDIR   budget: TIME_BUDGET_MS=$BUDGET_MS cap NMAX=$NMAX   external instrument: tools/bench_rusage"
echo
printf "%-24s %14s %14s %14s  %s\n" BENCHMARK m3/s m4/s rakudo/s check
printf "%-24s %14s %14s %14s  %s\n" "------------------------" "--------------" "--------------" "--------------" "-----"
tot_ok=0; tot_skip=0
for f in "$RDIR"/*.raku; do
  [ -e "$f" ] || continue
  k=$(basename "${f%.raku}"); ref="$RDIR/$k.ref"
  [ -f "$ref" ] || continue
  grep -qF "$WORK_OPEN" "$f" || continue   # only self-timed kernels have a WORK bracket to loop
  if [ -n "$KERNELS" ]; then case " $KERNELS " in *" $k "*) ;; *) continue ;; esac; fi

  # correctness gates the timing -- byte-exact via cmp, single-shot, all three engines, before any timing.
  # ⛔ USES THE FULL $T TIMEOUT, NOT A SHORT HARDCODED ONE: point_class_add/add1 alone cost ~20-26s on m3 --
  # a short correctness-check timeout would kill them mid-run and misreport a real answer as DIFF.
  ckstat=ok
  DECL_SW=(); dw=$(declared_switches_beside "$f") || { echo "⛔ REFUSED-TO-GRADE: $k: a .stack or .heap sidecar the reader refuses (it said why above)"; exit 2; }; [ -n "$dw" ] && read -r -a DECL_SW <<<"$dw"; undeclared_beside_named "$f" || true
  m3o="$W/m3o.$$"; (cd "$W" && timeout -k 5 "$T" "$SCRIP" --run "${DECL_SW[@]}" "$f" </dev/null >"$m3o" 2>/dev/null)
  cmp -s "$m3o" "$ref" || ckstat="m3:DIFF"
  if [ "$ckstat" = ok ]; then
    m4s="$W/m4c.$$.s"; m4b="$W/m4c.$$.bin"; m4o="$W/m4o.$$"
    if (cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile --out="$m4s" "$f" </dev/null >/dev/null 2>/dev/null) && [ -s "$m4s" ] \
       && as --64 -o "$m4s.o" "$m4s" 2>/dev/null && gcc -no-pie -o "$m4b" "$m4s.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null; then
      timeout -k 5 "$T" "$m4b" "${DECL_SW[@]}" </dev/null >"$m4o" 2>/dev/null; cmp -s "$m4o" "$ref" || ckstat="m4:DIFF"
    else ckstat="m4:BUILD-ERR"; fi
  fi
  if [ "$ckstat" = ok ]; then
    rko="$W/rko.$$"; (cd "$W" && timeout -k 5 "$T" "$RAKU" -I"$W/prelude" -Mprelude_rakudo "$f" </dev/null >"$rko" 2>/dev/null)
    cmp -s "$rko" "$ref" || ckstat="rakudo:DIFF"
  fi
  if [ "$ckstat" != ok ]; then
    printf "%-24s %14s %14s %14s  %s\n" "$k" SKIP SKIP SKIP "correctness-fail($ckstat)"; tot_skip=$((tot_skip+1)); continue
  fi

  declare -A R=() C=()
  for eng in m3 m4 rakudo; do
    res=$(search "$eng" "$f"); n=$(awk '{print $1}' <<<"$res")
    r=$(awk '{print $2}' <<<"$res")
    case "$r" in -) R[$eng]="NA"; C[$eng]="$eng@N=$n:$(cut -d' ' -f3- <<<"$res")" ;; *) R[$eng]="$r" ;; esac
  done
  ckstat=ok; for eng in m3 m4 rakudo; do [ -n "${C[$eng]:-}" ] && ckstat="${C[$eng]}"; done
  [ "$ckstat" = ok ] && tot_ok=$((tot_ok+1))
  printf "%-24s %14s %14s %14s  %s\n" "$k" "${R[m3]:-NA}" "${R[m4]:-NA}" "${R[rakudo]:-NA}" "$ckstat"
done
echo
echo "CHECK RESULT: measured=$tot_ok correctness-skip=$tot_skip"
[ "$tot_skip" -eq 0 ]
