#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_raku_fixed_iter.sh -- ANGLE 2 of the Raku three-angle triangulation (row
# bench-grids-rebase-to-two-number-basis), mirroring bench_prolog_fixed_iter.sh per
# ARCH-BENCH-CAMPAIGN-README-TABLES.md § THREE-ANGLE TRIANGULATION.
#
# Run EXACTLY N iterations of a kernel's WORK bracket (N fixed, COMMITTED, never a wall-clock deadline) and
# report throughput (iterations/s) for m3 / m4 / rakudo. Mirror of test_bench_raku_timed.sh (angle 1: LIVE
# auto-ranged search each run). Angle 2 instead reads N from corpus/benchmarks/raku/fixed-iter-n.tsv -- a
# small CHECKED-IN calibration table (kernel<TAB>N), analogous in role to Prolog's checked-in vanroy/<k>.pl
# wrappers but lighter-weight: Raku's derived twin is built ON THE FLY from N (via lib_raku_bench_wrap.sh),
# never checked into the corpus as its own .raku file -- a committed derived .raku would collide with
# test_gate_bench_rivals_coverage.sh's basename kernel-count (the same false-denominator class documented in
# that gate for src/ and vanroy/), so only the N NUMBER is committed, not generated source.
#
# ⛔ N IS CALIBRATED AGAINST m3, NOT PER-ENGINE -- documented, not hidden: SCRIP's own two modes (m3,
# m4) are the thing angles 1-3 exist to measure, so m3's cost is the one this harness must never blow a
# timeout on. Measured 2026-09-02: this is SAFE for all 4 currently self-timed kernels even though their
# per-unit costs span >5 orders of magnitude (point_class_add1 ~20-26s of m3 CPU time for a SINGLE run,
# string-escape ~microseconds) -- the two slow kernels calibrate to N=1 (a single execution already exceeds
# any sane floor) and the two fast kernels calibrate to a large N, and Rakudo's own per-unit cost on the
# same N never approached the TIMEOUT even where SCRIP is 10-25x slower or faster than Rakudo on the same
# kernel (see corpus/benchmarks/raku/worktime-*.tsv). Re-run --calibrate if a new kernel joins self-timing
# and its m3/rakudo cost ratio turns out to be far more extreme than today's 4.
#
# ⛔ CORRECTNESS IS NOT RE-VERIFIED HERE (bench_prolog_fixed_iter.sh's law, carried over verbatim): a kernel
# only gets a fixed-iter-n.tsv row after --calibrate's own single-shot m3/m4/rakudo-vs-.ref check passes at
# calibration time -- this script trusts that provenance and gates only on the run completing without
# crash/timeout. Re-verifying on every angle-2 invocation would require re-running the ORIGINAL (unlooped)
# kernel too, which angle 1 already does every time -- one authority, not two copies of the correctness check.
#
# External CPU time via tools/bench_rusage (user_us + sys_us), same instrument angle 1 and angle 3 both use.
#
# USAGE: bench_raku_fixed_iter.sh                 (read committed N, run angle 2)
#        bench_raku_fixed_iter.sh --calibrate      (re-derive N for every self-timed kernel, commit the TSV)
#        KERNELS="string-escape send-more-money-loops" bench_raku_fixed_iter.sh [--calibrate]
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
RDIR="${RAKU_DIR:-$S4E/corpus/benchmarks/raku}"
NTSV="${NTSV:-$RDIR/fixed-iter-n.tsv}"
T="${TIMEOUT:-120}"; CAL_BUDGET_MS="${CAL_BUDGET_MS:-3000}"; CAL_NMAX="${CAL_NMAX:-32768}"   # see test_bench_raku_timed.sh's header: >~49152 exhausts SCRIP's 1GB workspace island on string-escape (FINDING-2026-09-02-seat01)
KERNELS="${KERNELS:-}"
CALIBRATE=0; for a in "$@"; do [ "$a" = --calibrate ] && CALIBRATE=1; done
. "$HERE/lib_oracle_flags.sh"     2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot load lib_oracle_flags.sh"; exit 2; }
. "$HERE/lib_raku_bench_wrap.sh"  2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot load lib_raku_bench_wrap.sh"; exit 2; }
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

rate() { awk -v n="$1" -v us="$2" 'BEGIN{ if (us+0>0) printf "%.4f", n/(us/1e6); else print "NA" }'; }

# one bench_rusage-wrapped run of an already-wrapped source; echoes "cpu_us" or "- REASON"
run1() {
  local eng="$1" src="$2" rl xc user sys
  case "$eng" in
    m3)     "$WRAP" timeout -k 5 "$T" "$SCRIP" --run "${DECL_SW[@]}" "$src" </dev/null >/dev/null 2>"$W/e.$$" ;;
    m4)     local s="$W/$$.s" b="$W/$$.bin"
            if ! (cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile -o "$s" "$src" </dev/null >/dev/null 2>/dev/null) || [ ! -s "$s" ]; then echo "- BUILD-ERR"; return; fi
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

if [ "$CALIBRATE" -eq 1 ]; then
  echo "RAKU ANGLE-2 CALIBRATION -- deriving committed N per self-timed kernel, m3-referenced doubling search (floor=${CAL_BUDGET_MS}ms cpu, cap N=$CAL_NMAX)"
  declare -A NEW
  for f in "$RDIR"/*.raku; do
    [ -e "$f" ] || continue
    k=$(basename "${f%.raku}"); ref="$RDIR/$k.ref"
    [ -f "$ref" ] || continue
    grep -qF "$WORK_OPEN" "$f" || continue
    if [ -n "$KERNELS" ]; then case " $KERNELS " in *" $k "*) ;; *) continue ;; esac; fi
    # single-shot correctness on m3 first -- a kernel that cannot even run once correctly gets no N.
    DECL_SW=(); dw=$(declared_switches_beside "$f") || { echo "⛔ REFUSED-TO-GRADE: $k: a .stack or .heap sidecar the reader refuses (it said why above)"; exit 2; }; [ -n "$dw" ] && read -r -a DECL_SW <<<"$dw"; undeclared_beside_named "$f" || true
    o="$W/cal.$$"; (cd "$W" && timeout -k 5 "$T" "$SCRIP" --run "${DECL_SW[@]}" "$f" </dev/null >"$o" 2>/dev/null)
    if ! cmp -s "$o" "$ref"; then echo "  $k: SKIP (m3 single-shot does not match .ref)"; continue; fi
    N=1; cpu=0
    while :; do
      raku_bench_wrap "$f" "$N" "$W/cal.raku"
      cpu=$(run1 m3 "$W/cal.raku")
      case "$cpu" in -\ *) echo "  $k: SKIP (m3 failed mid-calibration at N=$N: $cpu)"; N=""; break ;; esac
      if [ "$cpu" -ge $((CAL_BUDGET_MS*1000)) ] || [ "$N" -ge "$CAL_NMAX" ]; then break; fi
      N=$((N*4)); [ "$N" -gt "$CAL_NMAX" ] && N="$CAL_NMAX"
    done
    [ -n "$N" ] || continue
    NEW["$k"]="$N"
    echo "  $k: N=$N (m3 cpu_us=$cpu)"
  done
  [ "${#NEW[@]}" -gt 0 ] || { echo "⛔ REFUSED: calibrated zero kernels -- nothing to commit." >&2; exit 2; }
  {
    echo -e "# fixed-iter-n.tsv -- committed N per Raku kernel for angle 2 (bench_raku_fixed_iter.sh), the historical"
    echo -e "# counterpart to angle 1's live search -- calibrated against m3 CPU time, floor ${CAL_BUDGET_MS}ms, cap $CAL_NMAX."
    echo -e "# Regenerate via 'bench_raku_fixed_iter.sh --calibrate', never hand-edit. One row per self-timed kernel."
    echo -e "kernel\tN"
    for k in "${!NEW[@]}"; do printf '%s\t%s\n' "$k" "${NEW[$k]}"; done | sort
  } > "$NTSV"
  echo; echo "wrote $NTSV"; exit 0
fi

[ -f "$NTSV" ] || { echo "⛔ REFUSED-TO-GRADE: $NTSV missing -- run 'bench_raku_fixed_iter.sh --calibrate' first" >&2; exit 2; }
declare -A NCOMMIT
while IFS=$'\t' read -r k n; do
  [[ "$k" == \#* || "$k" == "kernel" || -z "$k" ]] && continue
  NCOMMIT["$k"]="$n"
done < "$NTSV"
[ "${#NCOMMIT[@]}" -gt 0 ] || { echo "⛔ REFUSED-TO-GRADE: $NTSV carries zero kernel rows" >&2; exit 2; }

echo "FIXED-ITERATION RAKU BENCHMARKS -- angle 2: N fixed per kernel (committed in $NTSV), external cpu time measured"
echo "engines: m3 m4 rakudo   corpus: $RDIR   external instrument: tools/bench_rusage (user+sys cpu time)"
echo
printf "%-24s %8s %14s %14s %14s  %s\n" BENCHMARK N m3/s m4/s rakudo/s check
printf "%-24s %8s %14s %14s %14s  %s\n" "------------------------" "--------" "--------------" "--------------" "--------------" "-----"
tot_ok=0; tot_bad=0
for k in $(printf '%s\n' "${!NCOMMIT[@]}" | sort); do
  N="${NCOMMIT[$k]}"; f="$RDIR/$k.raku"
  [ -f "$f" ] || { printf "%-24s %8s   MISSING KERNEL SOURCE -- recalibrate\n" "$k" "-"; tot_bad=$((tot_bad+1)); continue; }
  if [ -n "$KERNELS" ]; then case " $KERNELS " in *" $k "*) ;; *) continue ;; esac; fi
  DECL_SW=(); dw=$(declared_switches_beside "$f") || { echo "⛔ REFUSED-TO-GRADE: $k: a .stack or .heap sidecar the reader refuses (it said why above)"; exit 2; }; [ -n "$dw" ] && read -r -a DECL_SW <<<"$dw"; undeclared_beside_named "$f" || true
  raku_bench_wrap "$f" "$N" "$W/r.$k.raku"
  ckstat=ok; declare -A RATE=()
  for eng in m3 m4 rakudo; do
    res=$(run1 "$eng" "$W/r.$k.raku"); cpu="$res"
    case "$cpu" in
      -\ *) RATE[$eng]="NA"; reason=$(cut -d' ' -f2- <<<"$cpu"); [ "$ckstat" = ok ] && ckstat="$eng:$reason" ;;
      *) RATE[$eng]=$(rate "$N" "$cpu") ;;
    esac
  done
  [ "$ckstat" = ok ] && tot_ok=$((tot_ok+1)) || tot_bad=$((tot_bad+1))
  printf "%-24s %8s %14s %14s %14s  %s\n" "$k" "$N" "${RATE[m3]}" "${RATE[m4]}" "${RATE[rakudo]}" "$ckstat"
done
echo
echo "CHECK RESULT: ok=$tot_ok bad=$tot_bad   (bad = crash/DNF/build-fail on at least one engine this run; correctness itself is angle 1's job)"
[ "$tot_bad" -eq 0 ]
