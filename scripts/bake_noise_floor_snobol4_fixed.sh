#!/usr/bin/env bash
# bake_noise_floor_snobol4_fixed.sh -- measure and record the run-to-run dispersion of the FIXED-WORK
# mode added to harness.inc (row bench-harness-unmeasurable, 2026-08-22).  Sibling of
# bake_noise_floor_snobol4_timed.sh, same NOISE-FLOOR.tsv, same statistics -- the only difference is
# WHAT is fed as stdin: a file holding one line, a positive integer (the kernel's pinned total
# iteration count), instead of /dev/null.  harness.inc treats that as the fixed-work switch: no
# calibration, no wall-clock deadline, ZBODY runs exactly that many iterations and stops.  Engine rows
# are suffixed "-fixed" so they sit BESIDE the existing time-based sbl/m3/m4 rows in the same file,
# per kernel, rather than in a second file -- the point is a reader can compare the two modes' noise
# floors on one line-adjacent group.  REPS defaults lower than the time-based bake (3 vs 5): fixed-work
# mode has no self-calibration loop to add jitter, so fewer reps already characterize the floor -- see
# the comparison table this script prints, which is the actual evidence, not an assumption.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200)." >&2; exit 3; }

SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
SBL="${SBL:-$(sbl_clean_bin)}"   # BENCHMARK oracle (s255) -- x64/bin/sbl carries a monitor-IPC bridge, ~2.2-3.5x slower
case " ${ENGINES:-sbl m3 m4} " in *" sbl "*) [ -x "$SBL" ] || { echo "⛔ ORACLE ABSENT: $SBL — the sbl rows of the noise floor would be fiction, not a benign gap. Build /home/resources/spitbol-bench-oracle (see RULES.md Oracles) -- seats do not clone x64 (s255). Or run with ENGINES=\"m3 m4\" to skip sbl entirely." >&2; exit 3; };; esac
B="${BENCH_DIR:-$S4E/corpus/benchmarks/snobol4}"
REPS="${REPS:-3}"; T="${TIMEOUT:-60}"; ENGINES="${ENGINES:-sbl m3 m4}"
NOHUGE="${NOHUGE:-1}"
# ⛔ SUPERSEDED 2026-09-28 (Lon, ceo CEO-1353, RULES.md hard-cap clause 8 (g)(4)): no typed SCRIP_HEAP_MB window. Each unit runs at the
# heap and stack declared beside it (<stem>.heap/.stack, lib_declared_arena.sh), the same switches to m3, the m4 binary and sbl.
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "REFUSING: lib_declared_arena.sh unloadable -- the one reader of a unit's declared heap and stack (CEO-1353)" >&2; exit 3; }
OUT="${OUT:-$B/NOISE-FLOOR.tsv}"
# hq_P 2026-09-05: this baker APPENDS its -fixed rows to a file the timed baker headed, so it must stamp its OWN
# oracle identity -- the two blocks are independently provenanced and can be baked days apart against different
# binaries.  Same law as the timed baker's header: an sbl row is a property of the exact binary that produced it.
{ echo "#"
  echo "#   FIXED-N BLOCK baked $(date -u +%Y-%m-%dT%H:%M:%SZ) by ../harness/scripts/$(basename "$0")  reps=$REPS  nivcsw_flag=$NIVCSW_FLAG"
  echo "#   MACHINE LOAD AT BAKE: nproc=$(nproc) loadavg=$(cut -d' ' -f1-3 /proc/loadavg)"
  echo "#   ORACLE IDENTITY AT BAKE: $(sbl_oracle_fingerprint "${SBL:-}")"
} >> "$OUT"
WRAP="$ROOT/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "FAIL build $WRAP" >&2; exit 1; }
NIVCSW_FLAG="${BENCH_NIVCSW_THRESHOLD:-20}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

# per-kernel pinned total (bench-harness-unmeasurable FINDING): representative of one native ~500ms
# TIME-mode run at bake time, rounded; keeps fixed-mode native wall cost in the same ballpark as the
# TIME-mode budget it replaces.  array_sum is skipped under callgrind (pre-existing valgrind SIGSEGV,
# unrelated defect) but has no trouble running fixed-mode natively, so it stays in this native bake.
declare -A FIXN=(
  [arith_loop]=75000000 [array_sum]=8192 [eval_fixed]=1500000 [fibonacci]=16384
  [func_call]=40000000 [indirect_dispatch]=2000000 [mixed_workload]=70000
  [op_dispatch]=30000000 [pattern_bt]=1200000 [roman]=100000 [string_concat]=7000000
  [string_manip]=1200000 [string_pattern]=2500000 [table_access]=4000 [var_access]=32000000
)

for sno in "$B"/*.sno; do
  [ -e "$sno" ] || continue
  s=$(basename "${sno%.sno}")
  n="${FIXN[$s]:-}"; [ -n "$n" ] || { echo "  SKIP $s (no fixed_n entry)"; continue; }
  # s265: fixed_n is BAKED into the twin by bench_wrap.sh --mode=iter instead of piped on stdin.  The
  # stdin gate could only ever reach a microbenchmark: a data-driven program reads its corpus from
  # stdin, so `fixed_n = INPUT` there consumes a line of DATA, never a count.  Baking makes
  # iteration-based measurement reachable for the whole corpus, which is what callgrind needs.
  bash "$HERE/bench_wrap.sh" "$sno" -o "$W/$s.bench.sno" --mode=iter --n="$n" >/dev/null || { echo "  ⛔ $s: not wrappable, skipped" >&2; continue; }
  SW="$(declared_switches_beside "$sno")" || { echo "  ⛔ $s: its .heap/.stack is refused (the reader said why above), skipped" >&2; continue; }
  [ -n "$SW" ] || { echo "  ⛔ $s: no .heap/.stack declared beside it (CEO-1353), skipped" >&2; continue; }
  sno="$W/$s.bench.sno"
  : > "$W/$s.stdin"
  case " $ENGINES " in *" sbl "*) sbl_clean_refuse_if_load "$sno" || exit 3;; esac
  m4ok=0
  if [ -x "$SCRIP" ]; then
    "$SCRIP" --compile "$sno" > "$W/$s.s" 2>/dev/null
    [ -s "$W/$s.s" ] && gcc -no-pie "$W/$s.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" \
        -o "$W/$s.prog" 2>/dev/null && m4ok=1
  fi
  for eng in $ENGINES; do
    if [ "$eng" = sbl ]; then thparm="n/a"; else thparm="nohuge=$NOHUGE"; fi
    : > "$W/self.txt"; : > "$W/elapsed.txt"; : > "$W/cpu.txt"
    used=0; contaminated=0; nivcsw_max=0
    for _ in $(seq 1 "$REPS"); do
      errfile="$W/r.err"
      case "$eng" in
        sbl) o=$("$WRAP" timeout -k 5 "$T" "$SBL" $(sbl_lang_flags) $SW "$sno" 2>"$errfile" <"$W/$s.stdin") ;;
        m3)  o=$(SCRIP_NOHUGE="$NOHUGE" "$WRAP" timeout -k 5 "$T" "$SCRIP" $SW --run "$sno" 2>"$errfile" <"$W/$s.stdin") ;;
        m4)  if [ "$m4ok" = 1 ]; then o=$(cd "$W" && SCRIP_NOHUGE="$NOHUGE" "$WRAP" timeout -k 5 "$T" "./$s.prog" $SW 2>"$errfile" <"$W/$s.stdin")
             else o=""; : > "$errfile"; fi ;;
      esac
      rusage_line=$(grep '^BENCH_RUSAGE:' "$errfile" | tail -1)
      [ -n "$rusage_line" ] || continue
      it=$(printf '%s\n' "$o" | sed -n 's/^iters: //p')
      ms=$(printf '%s\n' "$o" | sed -n 's/^ms: //p')
      nivcsw=$(echo "$rusage_line" | grep -oE 'nivcsw=[0-9]+' | cut -d= -f2); nivcsw="${nivcsw:-0}"
      elapsed_ns=$(echo "$rusage_line" | grep -oE 'elapsed_ns=[0-9]+' | cut -d= -f2)
      user_us=$(echo "$rusage_line" | grep -oE 'user_us=[0-9]+' | cut -d= -f2)
      sys_us=$(echo "$rusage_line" | grep -oE 'sys_us=[0-9]+' | cut -d= -f2)
      [ "$nivcsw" -gt "$nivcsw_max" ] 2>/dev/null && nivcsw_max=$nivcsw
      if [ "$nivcsw" -gt "$NIVCSW_FLAG" ] 2>/dev/null; then contaminated=$((contaminated+1)); continue; fi
      if [ -z "$it" ] || [ -z "$ms" ]; then continue; fi
      used=$((used+1))
      awk -v i="$it" -v m="$ms" 'BEGIN{ if(m+0>0) printf "%.3f\n", i/m*1000 }' >> "$W/self.txt"
      awk -v i="$it" -v ns="$elapsed_ns" 'BEGIN{ ems=ns/1000000; if(ems>0) printf "%.3f\n", i/ems*1000 }' >> "$W/elapsed.txt"
      awk -v i="$it" -v u="$user_us" -v y="$sys_us" 'BEGIN{ cms=(u+y)/1000; if(cms>0) printf "%.3f\n", i/cms*1000 }' >> "$W/cpu.txt"
    done
    awk -v selff="$W/self.txt" -v elapf="$W/elapsed.txt" -v cpuf="$W/cpu.txt" \
        -v b="$s" -v e="$eng-fixed" -v h="$thparm" -v rp="$REPS" -v used="$used" -v cont="$contaminated" -v nmax="$nivcsw_max" '
      function readfile(file, arr,    n,line) { n=0; while ((getline line < file) > 0) { n++; arr[n]=line+0 }; close(file); return n }
      function statsmm(file,    n,a,i,t,m,v,d,lo,hi,cv) {
        n=readfile(file,a); if (n<2) return "NA\tNA\tNA\tNA"
        t=0; for(i=1;i<=n;i++) t+=a[i]; m=t/n; v=0; for(i=1;i<=n;i++){d=a[i]-m; v+=d*d}; v=sqrt(v/n)
        lo=a[1]; hi=a[1]; for(i=1;i<=n;i++){ if(a[i]<lo) lo=a[i]; if(a[i]>hi) hi=a[i] }
        cv=100*v/m; return sprintf("%.0f\t%.1f\t%.2f\t%.1f", m, cv, (lo>0?hi/lo:0), 3*cv)
      }
      function stats(file,    n,a,i,t,m,v,d,cv) {
        n=readfile(file,a); if (n<2) return "NA\tNA\tNA"
        t=0; for(i=1;i<=n;i++) t+=a[i]; m=t/n; v=0; for(i=1;i<=n;i++){d=a[i]-m; v+=d*d}; v=sqrt(v/n)
        cv=100*v/m; return sprintf("%.0f\t%.1f\t%.1f", m, cv, 3*cv)
      }
      BEGIN { printf "%s\t%s\t%s\t%d\t%s\t%d\t%d\t%d\t%s\t%s\n", b, e, h, rp, statsmm(selff), used, cont, nmax, stats(elapf), stats(cpuf) }
    ' >> "$OUT"
  done
  echo "  floored $s (fixed_n=$n)"
done
echo
column -t -s $'\t' "$OUT" 2>/dev/null || cat "$OUT"
