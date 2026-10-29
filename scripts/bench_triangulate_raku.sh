#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_triangulate_raku.sh -- THE CROSS-PROOF SCAFFOLD for Raku (row bench-grids-rebase-to-two-number-basis,
# hq_B 2026-09-01), modelled on bench_triangulate_prolog.sh per ARCH-BENCH-CAMPAIGN-README-TABLES.md § THREE-ANGLE
# TRIANGULATION and Lon's 3-angle ruling (RULES.md § THE TWO-NUMBER BENCHMARK BASIS, second clause).
#
# ⛔⛔ ALL THREE ANGLES ARE NOW IMPLEMENTED (hq_B shipped angle 3 only, 2026-09-01; seat01 added 1+2, 2026-09-02):
#   angle 1 (fixed CPU-TIME, live-searched iterations) -- test_bench_raku_timed.sh, invoked fresh every run.
#   angle 2 (fixed ITERATIONS, committed N)             -- bench_raku_fixed_iter.sh, reads corpus/benchmarks/raku/
#                                                           fixed-iter-n.tsv (a committed calibration table, the
#                                                           lighter-weight Raku counterpart to Prolog's checked-in
#                                                           vanroy/<k>.pl wrappers -- see bench_raku_fixed_iter.sh's
#                                                           own header for why no derived .raku source is committed).
#   angle 3 (process wrapper: external elapsed via tools/bench_rusage + self-timed WORK from the kernel's own stderr
#            BENCH line; OVERHEAD = external - work)    -- unchanged, both units, every run byte-verified.
# Both angle 1 and angle 2 build their N-times-looped derived twin via lib_raku_bench_wrap.sh, which loops exactly
# the region the kernel's OWN wall_us()/wall_ms() bracket delimits (Raku kernels are top-level scripts, not callable
# predicates like Prolog's, so there is no clause head to rename -- see that lib's header for the scoping subtlety
# it exists to handle: a bracket-local `my $x` the kernel reads AFTER the loop must be hoisted, or Rakudo refuses
# to compile the wrap outright).
# ⛔ CROSS-PROOF, NOT AUTOMATIC AGREEMENT: a kernel/engine cell is MEASURED only when angle 1 and angle 2 AGREE
# within TOL_PCT (flat 10%, UNBAKED -- same as Prolog's own triangulator, no NOISE-FLOOR.tsv for raku either).
# The two slowest kernels (point_class_add, point_class_add1) calibrate to N=1 on both angles -- a SINGLE sample
# per engine per angle, no repetition -- so DISAGREE there is often measurement noise on a multi-second run, not a
# harness defect; it VOIDs the cell rather than publishing a noisy number, exactly as designed.
# ⭐ WHY THE WORK-BASIS NUMBERS STILL MATTER ON THEIR OWN: the two-number basis is the part that changes the
# published story -- it inverted the Prolog grid (ahead on 1 of 10, not 10 of 10) and it is what separates
# Rakudo's process startup from its engine speed. Angle 3's WORK/OVERHEAD split is published per kernel regardless
# of the angle-1-vs-2 cross-proof verdict, labelled with that verdict, never implied to be more than it is.
#
# ⛔ PRECONDITION THAT MUST SURVIVE ANY REWRITE (hq_P .github 682367fd; it fired live on the Prolog pass): no arm
# contributes to a multiple until its stdout is compared BYTE-FOR-BYTE against <kernel>.ref -- not exit code, not
# non-empty, and on EVERY rep, not just the first. A rival that prints a banner around the right answer passes every
# cheap guard and fails this one.
# ⛔ THE exit= FIELD OF THE BENCH_RUSAGE LINE IS THE ONLY CRASH SIGNAL (bench_prolog_fixed_iter.sh's law): a
# segfaulting child still prints a well-formed rusage line with exit=139; text-sniffing stderr passed one through.
# ⛔ INVARIANTS THAT VOID A CELL (an instrument lying about itself is worse than a missing number):
#   work_us > elapsed_us          -> VOID-CLOCK   (self-timed work cannot exceed the process that contains it)
#   |work_us/1000 - work_ms| > 1  -> VOID-UNITS   (same clock in two units; a disagreement is a unit bug)
# ⛔ THE RAKUDO PRELUDE IS STAGED IN A SCRATCH DIR, NEVER LOADED WITH -I<corpus dir>: Rakudo precompiles a -M module
# into a .precomp/ beside it, and `-I.` in corpus/benchmarks/raku/ wrote .precomp/ INTO THE CORPUS on the first
# hand run (the tmp1/tmp2 litter class ceo just deleted, 2026-09-01). The writer is the cure: this script copies
# prelude_rakudo.rakumod into $W and passes -I$W, so the corpus is never a Rakudo output directory.
# ⛔ FACT RULE / LABEL DUTY: every number names its arm and basis. Precision floors: SCRIP wall_us reads
# CLOCK_MONOTONIC (~20 ns back-to-back floor, reported in us); Rakudo wall_us reads `now` (sub-us Instant). Both
# arms are genuinely microsecond-precise -- unlike gprolog's 1 ms real_time floor that REFUSED the gplc column.
# RT_OPT is -O0 and there are no -O2 builds (Makefile:34).
#
# USAGE: bench_triangulate_raku.sh            (population = every self-timed kernel with a .ref)
#        KERNELS="string-escape send-more-money-loops" bench_triangulate_raku.sh
#        REPS=5 TIMEOUT=300 bench_triangulate_raku.sh
# EXIT: 0 = every cell verified AND every cross-proof cell (angle1 vs angle2) AGREEs or is honestly UNPROVEN.
#       1 = at least one cell DIFF / CRASH / VOID (angle 3), or at least one DISAGREE (angle1 vs angle2) --
#           do not publish or cite those cells.
#       2 = REFUSED -- missing scrip / rakudo / corpus / prelude / lib, loud, never a plausible table.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
RDIR="${RAKU_DIR:-$S4E/corpus/benchmarks/raku}"
REPS="${REPS:-3}"; T="${TIMEOUT:-120}"; KERNELS="${KERNELS:-}"; TOL="${TOL_PCT:-10}"
. "$HERE/lib_perf_fmt.sh"     2>/dev/null || { echo "⛔ REFUSED: cannot load lib_perf_fmt.sh -- the ONE authority for printing a multiple (s266)." >&2; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_oracle_flags.sh -- the ONE authority for rival binaries." >&2; exit 2; }
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED: cannot load lib_declared_arena.sh -- the ONE reader of a program's declared -d/-s sidecars (CEO-1283)." >&2; exit 2; }
# the kernel's declared heap and stack ride every SCRIP command line as -d/-s switches (its .heap/.stack sidecars; RULES.md hard-cap rule clause 8 (f))
dsw_of() { local dw; dw=$(declared_switches_beside "$1") || { echo "⛔ REFUSED: $1: a sidecar the reader refuses (it said why above)" >&2; exit 2; }; printf '%s' "$dw"; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSED: scrip not built ($SCRIP)." >&2; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED: libscrip_rt.so not built ($RT)." >&2; exit 2; }
[ -d "$RDIR" ] || { echo "⛔ REFUSED: raku bench corpus missing ($RDIR)." >&2; exit 2; }
[ -f "$RDIR/prelude_rakudo.rakumod" ] || { echo "⛔ REFUSED: $RDIR/prelude_rakudo.rakumod missing -- the Rakudo arm has no wall_us/wall_ms without it." >&2; exit 2; }
RAKU="$(rakudo_bin)" || exit 2
RAKU_VER="$("$RAKU" --version 2>/dev/null | sed -n 's/.*Rakudo™ v\([0-9][0-9.]*[0-9]\).*/\1/p' | head -1)"; RAKU_VER="${RAKU_VER:-unknown}"   # anchored on a digit at both ends: the banner reads "v2026.05." and a greedy [0-9.]* kept the sentence's full stop as part of the version
WRAP="$ROOT/tools/bench_rusage"; [ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED: bench_rusage failed to build." >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/prelude" && cp "$RDIR/prelude_rakudo.rakumod" "$W/prelude/" || { echo "⛔ REFUSED: cannot stage the prelude." >&2; exit 2; }
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_TSV="${OUT_TSV:-$RDIR/worktime-$TS.tsv}"

echo "RAKU THREE-ANGLE TRIANGULATION -- angle 3 (external elapsed + self-timed work -> overhead) cross-proved against angles 1+2 (fixed-time / fixed-iteration rate agreement)"
echo "arms: m3 (scrip --run) · m4 (scrip --compile, linked against libscrip_rt.so) · rakudo $RAKU_VER ($RAKU) -- REPS=$REPS best-of, TIMEOUT=${T}s, RT_OPT=-O0"
echo "basis: WORK = the kernel's own wall_us() bracket (stderr BENCH line); OVERHEAD = bench_rusage elapsed - WORK; every rep byte-verified against .ref"
echo "cross-proof: angle1_rate (test_bench_raku_timed.sh, live search) vs angle2_rate (bench_raku_fixed_iter.sh, committed N) -- AGREE within TOL_PCT=$TOL% (flat, UNBAKED)"
echo

# population: self-timed kernels (carry wall_us()) that have a .ref -- the rest are DECLARED here, never silently absent.
all=(); timed=(); untimed=(); noref=()
for f in "$RDIR"/*.raku; do
  k="$(basename "$f" .raku)"; all+=("$k")
  if [ -n "$KERNELS" ] && ! printf ' %s ' $KERNELS | grep -q " $k "; then continue; fi
  if [ ! -f "$RDIR/$k.ref" ]; then noref+=("$k"); continue; fi
  if grep -q 'wall_us()' "$f"; then timed+=("$k"); else untimed+=("$k"); fi
done
[ "${#all[@]}" -gt 0 ] || { echo "⛔ REFUSED: zero .raku kernels under $RDIR." >&2; exit 2; }
echo "population: ${#all[@]} kernels in corpus · ${#timed[@]} self-timed with .ref (measured below) · ${#untimed[@]} NOT SELF-TIMED (declared) · ${#noref[@]} without .ref (declared)"
[ "${#untimed[@]}" -gt 0 ] && echo "  not self-timed (add the wall_us()/note() bracket, then they join): ${untimed[*]}"
[ "${#noref[@]}"   -gt 0 ] && echo "  no .ref (cannot be byte-verified, so cannot be timed):           ${noref[*]}"
[ "${#timed[@]}" -gt 0 ] || { echo "⛔ REFUSED: no self-timed kernel with a .ref to measure." >&2; exit 2; }
for k in "${timed[@]}"; do undeclared_beside_named "$RDIR/$k.raku" || true; done
echo

# angles 1+2, run fresh and UNMODIFIED (one authority per mechanism, same discipline as bench_triangulate_prolog.sh):
# angle 1 does its own live doubling search; angle 2 reads its own committed fixed-iter-n.tsv. Restricted to the
# TIMED population this run already computed, so neither angle wastes wall-clock on an untimed/no-.ref kernel.
TIMED_STR="${timed[*]}"
A1_OUT="$(KERNELS="$TIMED_STR" bash "$HERE/test_bench_raku_timed.sh" 2>/dev/null)"
A2_OUT="$(KERNELS="$TIMED_STR" bash "$HERE/bench_raku_fixed_iter.sh" 2>/dev/null)"
declare -A A1 A2
parse_angle() { awk -v ncol="$1" 'done{next} /^-{5,}/{if(!seen){started=1;seen=1} next} started&&NF==0{started=0;done=1;next} started&&NF>=ncol{print}'; }
while read -r k m3v m4v rkv rest; do
  [ -z "$k" ] && continue
  A1["$k:m3"]="$m3v"; A1["$k:m4"]="$m4v"; A1["$k:rakudo"]="$rkv"
done < <(printf '%s\n' "$A1_OUT" | parse_angle 5)
while read -r k n m3v m4v rkv rest; do
  [ -z "$k" ] && continue
  A2["$k:m3"]="$m3v"; A2["$k:m4"]="$m4v"; A2["$k:rakudo"]="$rkv"
done < <(printf '%s\n' "$A2_OUT" | parse_angle 6)
dehuman() { awk -v v="$1" 'BEGIN{ if (v=="NA"||v=="-"||v=="") {print ""; exit} print v+0 }'; }
# cross-proof verdict for one cell -> "rate1 rate2 ratio VERDICT" (VERDICT: AGREE/DISAGREE/UNPROVEN)
crossproof() {
  local k="$1" eng="$2" r1 r2
  r1=$(dehuman "${A1["$k:$eng"]:-}"); r2=$(dehuman "${A2["$k:$eng"]:-}")
  if [ -n "$r1" ] && [ -n "$r2" ] && [ "$r1" != "0" ]; then
    awk -v a="$r1" -v b="$r2" -v t="$TOL" 'BEGIN{ ratio=b/a; lo=(100-t)/100; hi=(100+t)/100; printf "%s %s %.4f %s", a, b, ratio, (ratio>=lo && ratio<=hi) ? "AGREE" : "DISAGREE" }'
  else
    printf '%s %s %s %s' "${r1:-NA}" "${r2:-NA}" "-" "UNPROVEN"
  fi
}

# disk telemetry (angle 3's third leg, same convention as bench_triangulate_prolog.sh): one direct m3 sample per
# kernel. Expected ~0 for these in-memory kernels; nonzero is a finding, not folded into AGREE/DISAGREE.
disk_sample() {  # echoes "inblock oublock" (each may be empty if the BENCH_RUSAGE line lacks the field)
  local k="$1" dline ib ob
  dline=$("$WRAP" "$SCRIP" --run $(dsw_of "$RDIR/$k.raku") "$RDIR/$k.raku" < /dev/null 2>&1 >/dev/null | grep '^BENCH_RUSAGE:' | tail -1)
  ib=$(echo "$dline" | grep -oE 'inblock=[0-9]+' | cut -d= -f2); ob=$(echo "$dline" | grep -oE 'oublock=[0-9]+' | cut -d= -f2)
  printf '%s %s' "${ib:-}" "${ob:-}"
}

# one wrapped run -> "work_us work_ms elapsed_us" on success, or "- - - <REASON>" (never a number with a reason)
run1() {
  local eng="$1" k="$2" src="$RDIR/$2.raku" so="$W/so.$$" se="$W/se.$$" rl xc wu wm el
  case "$eng" in
    m3)     "$WRAP" timeout -k 5 "$T" "$SCRIP" --run $(dsw_of "$src") "$src" </dev/null >"$so" 2>"$se" ;;
    m4)     "$WRAP" timeout -k 5 "$T" "$W/$k.bin" $(dsw_of "$src") </dev/null >"$so" 2>"$se" ;;
    rakudo) "$WRAP" timeout -k 5 "$T" "$RAKU" -I"$W/prelude" -Mprelude_rakudo "$src" </dev/null >"$so" 2>"$se" ;;
  esac
  rl=$(grep '^BENCH_RUSAGE:' "$se" 2>/dev/null | tail -1); [ -n "$rl" ] || { echo "- - - DNF"; return; }
  xc=$(echo "$rl" | grep -oE 'exit=[0-9-]+' | cut -d= -f2)
  case "$xc" in ''|*[!0-9]*) echo "- - - CRASH(exit=${xc:-?})"; return ;; esac
  [ "$xc" -ge 128 ] && { echo "- - - CRASH(signal $((xc-128)))"; return; }
  [ "$xc" -ne 0 ] && { echo "- - - NONZERO($xc)"; return; }
  cmp -s "$so" "$RDIR/$k.ref" || { echo "- - - DIFF"; return; }
  wu=$(grep -oE 'BENCH kernel=[^ ]+ work_us=[0-9]+' "$se" | tail -1 | grep -oE 'work_us=[0-9]+' | cut -d= -f2)
  wm=$(grep -oE 'work_ms=[0-9]+' "$se" | tail -1 | cut -d= -f2)
  [ -n "$wu" ] && [ -n "$wm" ] || { echo "- - - NO-BENCH-LINE"; return; }
  el=$(( $(echo "$rl" | grep -oE 'elapsed_ns=[0-9]+' | cut -d= -f2) / 1000 ))
  [ "$wu" -le "$el" ] || { echo "- - - VOID-CLOCK(work_us=$wu>elapsed_us=$el)"; return; }
  awk -v u="$wu" -v m="$wm" 'BEGIN{ d=u/1000-m; if (d<0) d=-d; exit (d<=1)?0:1 }' || { echo "- - - VOID-UNITS(work_us=$wu work_ms=$wm)"; return; }
  echo "$wu $wm $el"
}
build_m4() {  # compile+link once per kernel; the .s and .bin live in $W, never beside the kernel
  local k="$1" s="$W/$1.s" o="$W/$1.o" b="$W/$1.bin"
  (cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile --out="$s" "$RDIR/$k.raku" </dev/null >/dev/null 2>"$W/$k.m4build.err") && [ -s "$s" ] || return 1
  as --64 -o "$o" "$s" 2>>"$W/$k.m4build.err" && gcc -no-pie -o "$b" "$o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>>"$W/$k.m4build.err"
}

{ echo -e "# raku work-time TSV -- $TS -- angle 3 detail (work/overhead/spread), angle1/angle2/crossproof columns filled from the live cross-proof -- never hand-edit, regenerate via bench_triangulate_raku.sh"
  echo -e "# arms: m3 · m4 · rakudo $RAKU_VER; REPS=$REPS best-of by work_us; overhead_us = elapsed_us - work_us of the best rep; spread_pct = (max-min)/min of work_us over verified reps; floor_us = clock floor of the arm"
  echo -e "kernel\tengine\treps_ok\twork_us\twork_ms\telapsed_us\toverhead_us\tspread_pct\tverified\tfloor_us\tangle1\tangle2\tcrossproof"; } > "$OUT_TSV"
# companion TSV in bench_triangulate_prolog.sh's OWN 8-column schema (kernel engine angle1_rate angle2_rate ratio
# verdict disk_inblock disk_oublock) -- test_gate_bench_rivals_coverage.sh globs "$DIR"/triangulation-*.tsv and
# reads column 6 as the AGREE/DISAGREE/UNPROVEN verdict; it does not know worktime-*.tsv's richer 13-column shape.
# ⛔ FOUND LIVE, THIS ROW (seat01 2026-09-02): before this file existed, the coverage gate could never see a Raku
# AGREE even once angles 1+2 landed -- a naming/schema mismatch with the SAME failure shape as the src/+vanroy/ and
# prelude_*/epilogue_* false-denominator classes that gate's own header already documents one layer up.
TRI_TSV="${TRI_TSV:-$RDIR/triangulation-$TS.tsv}"
{ echo -e "# triangulation TSV -- $TS -- TOL_PCT=$TOL (flat, UNBAKED) -- schema matches bench_triangulate_prolog.sh so test_gate_bench_rivals_coverage.sh reads it uniformly -- never hand-edit, regenerate via bench_triangulate_raku.sh"
  echo -e "kernel\tengine\tangle1_rate\tangle2_rate\tratio\tverdict\tdisk_inblock\tdisk_oublock"; } > "$TRI_TSV"

declare -A BW BO BE BN BS   # best work_us, its overhead, its elapsed, ok-rep count, spread pct -- keyed k:eng
any_bad=0; any_disagree=0
printf '%-24s %-7s %4s %14s %14s %14s %9s  %s\n' kernel engine reps work_us elapsed_us overhead_us spread verdict
printf '%s\n' "-------------------------------------------------------------------------------------------------------"
for k in "${timed[@]}"; do
  m4ok=1; build_m4 "$k" || m4ok=0
  read -r dib dob <<<"$(disk_sample "$k")"
  for eng in m3 m4 rakudo; do
    best=""; bo=""; be=""; ok=0; reason=""; mn=""; mx=""
    if [ "$eng" = m4 ] && [ "$m4ok" -eq 0 ]; then reason="BUILD-ERR"; else
      for ((r=1; r<=REPS; r++)); do
        read -r wu wm el rest <<<"$(run1 "$eng" "$k")"
        if [ "$wu" = "-" ]; then reason="${reason:-$rest}"; continue; fi
        ok=$((ok+1)); [ -z "$mn" ] || [ "$wu" -lt "$mn" ] && mn="$wu"; [ -z "$mx" ] || [ "$wu" -gt "$mx" ] && mx="$wu"
        if [ -z "$best" ] || [ "$wu" -lt "$best" ]; then best="$wu"; bwm="$wm"; be="$el"; bo=$((el-wu)); fi
      done
    fi
    floor=1   # both arms report integer us: SCRIP quantizes a ~20 ns CLOCK_MONOTONIC read to 1 us, Rakudo a sub-us Instant to 1 us
    read -r cp_r1 cp_r2 cp_ratio cp_verdict <<<"$(crossproof "$k" "$eng")"
    [ "$cp_verdict" = DISAGREE ] && any_disagree=1
    if [ "$ok" -gt 0 ] && [ -z "$reason" ]; then
      sp=$(awk -v a="$mn" -v b="$mx" 'BEGIN{ if (a+0>0) printf "%.1f", (b-a)*100/a; else print "NA" }')
      BW["$k:$eng"]="$best"; BO["$k:$eng"]="$bo"; BE["$k:$eng"]="$be"; BN["$k:$eng"]="$ok"; BS["$k:$eng"]="$sp"
      printf '%-24s %-7s %4s %14s %14s %14s %8s%%  %s\n' "$k" "$eng" "$ok/$REPS" "$best" "$be" "$bo" "$sp" "VERIFIED (cross-proof: $cp_verdict)"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$k" "$eng" "$ok/$REPS" "$best" "$bwm" "$be" "$bo" "$sp" VERIFIED "$floor" "$cp_r1" "$cp_r2" "$cp_verdict" >> "$OUT_TSV"
    else
      any_bad=1
      # a partial success (some reps verified, one did not) is still a bad cell: the arm is not reproducible, and a
      # best-of over a set that contains a DIFF would be choosing the run whose answer we did not check
      printf '%-24s %-7s %4s %14s %14s %14s %9s  %s\n' "$k" "$eng" "$ok/$REPS" - - - - "⛔ ${reason:-UNVERIFIED}"
      printf '%s\t%s\t%s\t-\t-\t-\t-\t-\t%s\t%s\t%s\t%s\t%s\n' "$k" "$eng" "$ok/$REPS" "${reason:-UNVERIFIED}" "$floor" "$cp_r1" "$cp_r2" "$cp_verdict" >> "$OUT_TSV"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$k" "$eng" "$cp_r1" "$cp_r2" "$cp_ratio" "$cp_verdict" "${dib:-}" "${dob:-}" >> "$TRI_TSV"
  done
done

echo
grid_incomplete=0
perf_grid_begin "FACT-RULE grid: WORK basis (angle 3, single angle -- label it so). multiple = rakudo work_us / SCRIP work_us; >1.000x means SCRIP does the kernel's work faster"
for k in "${timed[@]}"; do
  rw="${BW["$k:rakudo"]:-}"; w3="${BW["$k:m3"]:-}"; w4="${BW["$k:m4"]:-}"
  perf_row_or_refuse "$k  m3 vs rakudo" "$rw" "$w3"
  perf_row_or_refuse "$k  m4 vs rakudo" "$rw" "$w4"
  [ -z "$rw" ] && echo "  $k: rakudo arm unverified -- the REFUSED cells above name the kernel; this line names the reason"
done
perf_grid_end || grid_incomplete=1
echo
echo "-- OVERHEAD per engine (elapsed - work, us, of each kernel's best rep): the process/startup constant the totals basis was charging to the engine --"
for eng in m3 m4 rakudo; do
  line=""; for k in "${timed[@]}"; do o="${BO["$k:$eng"]:-}"; [ -n "$o" ] && line="$line $k=$o"; done
  printf '  %-7s%s\n' "$eng" "${line:- (no verified cell)}"
done
echo
echo "-- CROSS-PROOF grid: angle1 (live search) vs angle2 (committed N) rate agreement, per kernel x engine --"
for k in "${timed[@]}"; do
  for eng in m3 m4 rakudo; do
    read -r r1 r2 ratio verdict <<<"$(crossproof "$k" "$eng")"
    printf '  %-24s %-7s angle1=%-12s angle2=%-12s ratio=%-8s %s\n' "$k" "$eng" "$r1" "$r2" "$ratio" "$verdict"
  done
done
echo
echo "TSV: $OUT_TSV"
if [ "${CHECK_SHAPE:-0}" != 1 ]; then . "$HERE/lib_progress.sh"; progress_append_triangulation raku "$OUT_TSV" || { echo "⛔ bench_triangulate_raku: the progress database did not take this run's kernels (see above) -- a benchmark run that leaves the table untouched is a defect of the run (progress/README.md, CEO-331)"; exit 2; }; fi
echo "TSV: $TRI_TSV (coverage-gate schema)"
if [ "$any_disagree" -eq 1 ]; then echo "⛔ DISAGREE present in the cross-proof -- VOID: do not publish or cite those kernel/engine cells until re-measured."; fi
if [ "$any_bad" -eq 1 ]; then echo "⛔ at least one angle-3 cell is DIFF/CRASH/VOID/BUILD-ERR -- do not publish or cite those cells."; fi
if [ "$any_bad" -eq 1 ] || [ "$any_disagree" -eq 1 ]; then exit 1; fi
if [ "$grid_incomplete" -eq 1 ]; then
  echo "⛔ the FACT-RULE grid above is INCOMPLETE -- a cell REFUSED (its subject is named on stderr). VOID as a reading: a dark cell is worse than a red one (CEO-676), so do not publish or cite this grid until every cell measures."
  exit 1
fi
echo "every measured cell VERIFIED (byte-equal stdout on every rep, clock and unit invariants held); no DISAGREE in the cross-proof (AGREE or honestly UNPROVEN)."
exit 0
