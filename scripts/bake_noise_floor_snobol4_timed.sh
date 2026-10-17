#!/usr/bin/env bash
# bake_noise_floor_snobol4_timed.sh -- measure and record the RUN-TO-RUN
# dispersion of every (benchmark, engine) row in the TIME-based family.
#
# ⛔ WHY THIS EXISTS.  A benchmark instrument that does not know its own noise
# floor cannot tell a regression from weather.  s148 convicted the md5 blast
# -radius sweep for exactly this.  The trap repeated itself here in a subtler
# form: the floor was first measured on ONE kernel (arith_loop, cv 1.3%) and
# was about to be written into the runner as a GLOBAL "~4%" constant.  Measured
# per row, the real spread is 0.7% .. 37.7% -- the floor is a property of the
# (KERNEL, ENGINE) PAIR, not of the harness.  Generalising one row's floor to
# the suite is the same error in new clothes, so the floor is baked per row.
#
# ⛔ row bench-external-cpu-and-elapsed-clock (Lon s200 directive, FINDING-2026-08-22-s253):
# every rep below is now ALSO measured by tools/bench_rusage -- ONE external instrument, blind to
# which engine it times, forked around each rep and read via wait4()'s rusage.  self(ms)/cv_pct/
# maxmin/min_detectable_pct (columns 1-8) are UNCHANGED -- still each engine's own TIME() self-report,
# kept for continuity and still what test_bench_snobol4_timed.sh's live board reads for m3/sbl output,
# but per the s200 finding SPITBOL's TIME() is CPU-time-patched and SCRIP's is wall-clock, so the two
# were never the same unit -- self(ms) is NEVER AGAIN the cross-engine authority.  New columns 9-17
# add: used/contaminated/nivcsw_max (a rep whose nivcsw exceeds $BENCH_NIVCSW_THRESHOLD, default 20,
# is EXCLUDED from every mean below, not averaged in -- the mechanical cure for the 47.9% floor), then
# elapsed (CLOCK_MONOTONIC, external) and cpu (external user+sys) mean/cv/min_detectable triples.  CPU
# is the new cross-engine authority; ELAPSED is reported alongside so the two min_detectable_pct
# columns can be read BY NAME side by side -- CPU should read tighter under load since a descheduled
# millisecond counts against elapsed but not against cpu.
#
# Output: corpus/benchmarks/snobol4/NOISE-FLOOR.tsv
#   bench  engine  reps  mean_per_s  cv_pct  maxmin  min_detectable_pct  [self, columns 1-8, unchanged]
#   used  contaminated  nivcsw_max                                      [columns 9-11]
#   mean_per_s_elapsed  cv_elapsed_pct  min_detectable_elapsed_pct       [columns 12-14, external]
#   mean_per_s_cpu  cv_cpu_pct  min_detectable_cpu_pct                  [columns 15-17, external]
# min_detectable_pct = 3*cv, the difference below which a single-run delta on
# that row must NOT be called real.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200). A private fallback would time a DIFFERENT LANGUAGE (s189: -bf is the only correct arm). Fix the checkout; do not work around this." >&2; exit 3; }

SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
SBL="${SBL:-$(sbl_clean_bin)}"   # BENCHMARK oracle (s255) -- x64/bin/sbl carries a monitor-IPC bridge, ~2.2-3.5x slower
case " ${ENGINES:-sbl m3 m4} " in *" sbl "*) [ -x "$SBL" ] || { echo "⛔ ORACLE ABSENT: $SBL — the sbl rows of the noise floor would be fiction, not a benign gap. Build /home/resources/spitbol-bench-oracle (see RULES.md Oracles) -- seats do not clone x64 (s255). Or run with ENGINES=\"m3 m4\" to skip sbl entirely." >&2; exit 3; };; esac
B="${BENCH_DIR:-$S4E/corpus/benchmarks/snobol4}"  # BM-ONE (s153): promoted, see test_bench_snobol4_timed.sh
REPS="${REPS:-5}"; T="${TIMEOUT:-60}"; ENGINES="${ENGINES:-sbl m3 m4}"
APPEND="${APPEND:-0}"; NOHUGE="${NOHUGE:-1}"
# ⛔ SUPERSEDED 2026-09-28 (Lon, ceo CEO-1353, RULES.md hard-cap clause 8 (g)(4)): no typed SCRIP_HEAP_MB window. Each unit runs at the
# heap and stack declared beside it (<stem>.heap/.stack, lib_declared_arena.sh), the same switches to m3, the m4 binary and sbl.
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "REFUSING: lib_declared_arena.sh unloadable -- the one reader of a unit's declared heap and stack (CEO-1353)" >&2; exit 3; }
OUT="${OUT:-$B/NOISE-FLOOR.tsv}"
WRAP="$ROOT/tools/bench_rusage"   # row bench-external-cpu-and-elapsed-clock: the external stopwatch, built on demand (not tracked -- see .gitignore)
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "FAIL build $WRAP" >&2; exit 1; }
NIVCSW_FLAG="${BENCH_NIVCSW_THRESHOLD:-20}"   # same knob/default as util_bench_snobol4_engines.sh -- one instrument, one threshold
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
if [ "$APPEND" != 1 ]; then
{
  echo "# TIME-based SNOBOL4 benchmarks -- MEASURED run-to-run noise floor"
  echo "# baked $(date -u +%Y-%m-%dT%H:%M:%SZ) by ../harness/scripts/$(basename "$0")  reps=$REPS  nivcsw_flag=$NIVCSW_FLAG"
echo "#   MACHINE LOAD AT BAKE: nproc=$(nproc) loadavg=$(cut -d' ' -f1-3 /proc/loadavg)"
echo "#   ORACLE IDENTITY AT BAKE: $(sbl_oracle_fingerprint "$SBL")"
echo "#   ⛔ THE sbl ROWS BELOW ARE A PROPERTY OF THAT EXACT BINARY.  A rebuilt or repaired oracle makes them"
echo "#   numbers from a DIFFERENT engine sitting in the same column as new ones -- re-bake, never carry across."
echo "#   ⛔ THE FLOOR IS A PROPERTY OF MACHINE LOAD, NOT ONLY OF THE ENGINE (s200).  The 2026-08-20 bake ran"
echo "#   while EIGHT fleet seats shared this box and its min_detectable reached 47.9% -- a floor that wide"
echo "#   cannot see a 1.4x regression.  A solo re-bake of the SAME binaries moved sbl +20.9% and m3 +13.0%,"
echo "#   i.e. the shift was LOAD, not the engine and not the oracle flag: -b vs -bf measured back-to-back on a"
echo "#   quiet box is -0.3% (+/-2.6%), ZERO.  ⛔ NEVER compare a floor baked under load with one baked solo."
  echo "# SCRIP_NOHUGE=$NOHUGE  heap/stack: each unit's declared .heap/.stack (CEO-1353)  (no typed window; a collection"
  echo "#   collection fires inside it -- a GC row measures an ~835ms stall, not dispersion)"
  echo "# ⛔ THE ALLOCATING ROWS' DISPERSION WAS THE GC STALL LOTTERY, NOT THP (BM-3 correction):"
  echo "#   whether an ~835ms regeneration lands inside the window is a coin flip, and it was being"
  echo "#   baked as variance.  GC-free, table_access m3 goes cv 12.4%->1.9% and array_sum 10.9%->0.5%."
  echo "# min_detectable_pct = 3*cv; a single-run delta smaller than this is WEATHER."
  echo "# ⛔ COLUMNS 1-8 (self.../min_detectable_pct) are the ORIGINAL self-timed TIME() statistic --"
  echo "#   kept for continuity, still what test_bench_snobol4_timed.sh's live board historically read,"
  echo "#   but per FINDING-2026-08-22-s253 SPITBOL's TIME() is CPU-time-patched and SCRIP's is wall-clock,"
  echo "#   so the two were never the same unit.  self(ms) is NEVER AGAIN the cross-engine authority."
  echo "# ⛔ COLUMNS 12-17 (elapsed/cpu) are measured by tools/bench_rusage -- ONE external instrument"
  echo "#   outside both engines, forked around each rep, read via wait4()'s rusage.  A rep whose nivcsw"
  echo "#   exceeds nivcsw_flag (see header line above) is EXCLUDED from every mean, not averaged in --"
  echo "#   the mechanical cure for the 47.9% floor.  cpu(user+sys) is the new cross-engine authority;"
  echo "#   elapsed is reported alongside so min_detectable_cpu_pct and min_detectable_elapsed_pct can be"
  echo "#   read BY NAME side by side -- cpu should read tighter under load (a descheduled ms counts"
  echo "#   against elapsed but not against cpu)."
  printf "bench\tengine\tthp\treps\tmean_per_s\tcv_pct\tmaxmin\tmin_detectable_pct\tused\tcontaminated\tnivcsw_max\tmean_per_s_elapsed\tcv_elapsed_pct\tmin_detectable_elapsed_pct\tmean_per_s_cpu\tcv_cpu_pct\tmin_detectable_cpu_pct\n"
} > "$OUT"
fi
for sno in "$B"/*.sno; do
  [ -e "$sno" ] || continue
  s=$(basename "${sno%.sno}")
  # s265: the corpus holds standalone APPLICATIONS now; the timed twin that emits iters:/ms: is built
  # here, on the fly, from the program's *BENCH marker.  A program without one is not timeable and is
  # named on stderr rather than silently skipped (the old gate's failure mode).
  bash "$HERE/bench_wrap.sh" "$sno" -o "$W/$s.bench.sno" >/dev/null || { echo "  ⛔ $s: not wrappable, skipped" >&2; continue; }
  SW="$(declared_switches_beside "$sno")" || { echo "  ⛔ $s: its .heap/.stack is refused (the reader said why above), skipped" >&2; continue; }
  [ -n "$SW" ] || { echo "  ⛔ $s: no .heap/.stack declared beside it (CEO-1353), skipped" >&2; continue; }
  sno="$W/$s.bench.sno"
  case " $ENGINES " in *" sbl "*) sbl_clean_refuse_if_load "$sno" || exit 3;; esac
  # build the mode-4 program ONCE, not once per rep
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
        sbl) o=$("$WRAP" timeout -k 5 "$T" "$SBL" $(sbl_lang_flags) $SW "$sno" 2>"$errfile" </dev/null) ;;
        m3)  o=$(SCRIP_NOHUGE="$NOHUGE" "$WRAP" timeout -k 5 "$T" "$SCRIP" $SW --run "$sno" 2>"$errfile" </dev/null) ;;
        m4)  if [ "$m4ok" = 1 ]; then o=$(cd "$W" && SCRIP_NOHUGE="$NOHUGE" "$WRAP" timeout -k 5 "$T" "./$s.prog" $SW 2>"$errfile" </dev/null)
             else o=""; : > "$errfile"; fi ;;
      esac
      rusage_line=$(grep '^BENCH_RUSAGE:' "$errfile" | tail -1)
      [ -n "$rusage_line" ] || continue   # build/run never reached bench_rusage's report -- no sample, not even a contaminated one
      it=$(printf '%s\n' "$o" | sed -n 's/^iters: //p')
      ms=$(printf '%s\n' "$o" | sed -n 's/^ms: //p')
      nivcsw=$(echo "$rusage_line" | grep -oE 'nivcsw=[0-9]+' | cut -d= -f2); nivcsw="${nivcsw:-0}"
      elapsed_ns=$(echo "$rusage_line" | grep -oE 'elapsed_ns=[0-9]+' | cut -d= -f2)
      user_us=$(echo "$rusage_line" | grep -oE 'user_us=[0-9]+' | cut -d= -f2)
      sys_us=$(echo "$rusage_line" | grep -oE 'sys_us=[0-9]+' | cut -d= -f2)
      [ "$nivcsw" -gt "$nivcsw_max" ] 2>/dev/null && nivcsw_max=$nivcsw
      if [ "$nivcsw" -gt "$NIVCSW_FLAG" ] 2>/dev/null; then contaminated=$((contaminated+1)); continue; fi
      if [ -z "$it" ] || [ -z "$ms" ]; then continue; fi   # program didn't complete its harness -- no usable sample
      used=$((used+1))
      awk -v i="$it" -v m="$ms" 'BEGIN{ if(m+0>0) printf "%.3f\n", i/m*1000 }' >> "$W/self.txt"
      awk -v i="$it" -v ns="$elapsed_ns" 'BEGIN{ ems=ns/1000000; if(ems>0) printf "%.3f\n", i/ems*1000 }' >> "$W/elapsed.txt"
      awk -v i="$it" -v u="$user_us" -v y="$sys_us" 'BEGIN{ cms=(u+y)/1000; if(cms>0) printf "%.3f\n", i/cms*1000 }' >> "$W/cpu.txt"
    done
    awk -v selff="$W/self.txt" -v elapf="$W/elapsed.txt" -v cpuf="$W/cpu.txt" \
        -v b="$s" -v e="$eng" -v h="$thparm" -v rp="$REPS" -v used="$used" -v cont="$contaminated" -v nmax="$nivcsw_max" '
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
  echo "  floored $s"
done
echo
column -t -s $'\t' "$OUT" 2>/dev/null || cat "$OUT"
