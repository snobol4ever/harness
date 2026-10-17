#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
# bench_prolog_perf.sh — ANGLE 3 of the Prolog three-angle triangulation: THE PROCESS WRAPPER.
#
# TWO BASES, PRINTED SEPARATELY AND NEVER SUBTRACTED ACROSS (RULES.md FACT RULE, apples-to-apples):
#
#   (A) PROCESS TOTALS, wall ms, median of RUNS, over the PRISTINE kernel — the table this harness has
#       always printed.  Columns: GNU ("$(gprolog_bin)" --consult-file, bytecode consult mode) · SWI (swipl -q -g
#       halt, script mode) · m3 (scrip --run: in-process x86 codegen + execution, end to end) · m4r (the
#       precompiled scrip --compile binary, execution only) · m4c (scrip --compile + as + gcc, one-shot
#       compile+link).  Single-shot, so small entries are startup-dominated — stated up front, and that
#       IS this angle's subject: m4c exists on no other angle.
#
#   (B) ⭐ THE TWO-NUMBER WORK/OVERHEAD BASIS, over the GENERATED WRAPPED FORM — the CEO-567 DONE-WHEN
#       clause "the three angles run over the wrapped form with the process wrapper's numbers printed
#       beside the self-measured ones".  Angle 1 (test_bench_prolog_timed.sh) and angle 2
#       (bench_prolog_fixed_iter.sh) have carried these two grids since 2026-09-13; this angle was the
#       last of the three without them, so the row's own DONE-WHEN could not close.  ELAPSED comes from
#       tools/bench_rusage OUTSIDE the process, WORK from the generated bracket INSIDE it, and
#       OVERHEAD is the difference — the startup + consult/codegen + teardown the kernel never did,
#       which on a single-shot angle is most of the wall clock and is the whole point of measuring here.
#
# ⛔⛔ (A) AND (B) MEASURE DIFFERENT PROGRAMS AND A READER MUST NOT SUBTRACT ONE FROM THE OTHER.
#   (A) runs corpus/benchmarks/prolog/bench/<k>.pl verbatim; (B) runs the generated wrapper, which for a
#   rival also inlines its prelude (wall_us/1, wall_ms/1).  The two differ by a timing bracket and, on
#   gnu/swi, by a consulted prelude.  Each table states its own program; neither is the other's control.
#
# ⛔ THE PAIR IN (B) COMES FROM ONE RUN, NEVER FROM TWO MEDIANS.  OVERHEAD = ELAPSED − WORK is a
#   difference taken inside a single process; median-of-elapsed and median-of-work can come from
#   different runs, and their difference is then a number no process ever exhibited.  So the runs are
#   ranked by ELAPSED and the MEDIAN RUN's own (elapsed, work) pair is what is printed — both cells of a
#   row are the same process, always.
#
# ⛔⛔ WALL MINUS WALL (the same law angles 1 and 2 carry).  bench_rusage reports BOTH elapsed_ns
#   (CLOCK_MONOTONIC) and user_us+sys_us (CPU); wall_us/1 inside the bracket is CLOCK_MONOTONIC.  So
#   OVERHEAD uses elapsed_ns and never the CPU pair — subtracting across the two instruments publishes
#   the difference of two clocks as an overhead, and goes NEGATIVE on a loaded box, which is the tell.
#
# ⛔⭐ THE CLOCK FLOOR IS A REFUSAL, NOT A FOOTNOTE (hq_P's ruling to the ceo, row CEO-567 conversion).
#   gprolog's wall_us is real_time/1 × 1000 — a UNIT CONVERSION of a 1 ms tick, which prelude_gplc.pl
#   says in its own header.  On this angle the work is ONE iteration, so most kernels' true work is far
#   under one gnu tick: MEASURED here, gnu reports work_us=0 for query.  A zero silently moves the whole
#   elapsed into the OVERHEAD column and reads as "this engine did no work", which is readable and
#   wrong.  A cell whose work is under FLOOR_TICKS ticks of ITS OWN engine's clock therefore prints
#   TICK-FLOOR(<what it read>) in both grids: what it read, and no number built on it.
#   ⭐ A TICK-FLOOR CELL IS A MEASUREMENT, NOT A DARK CELL, and it does not make the grid refuse -- the
#   caller knows its subject is below its instrument and says so in its own words, which is precisely the
#   case lib_perf_fmt.sh THE DARK-CELL LAW exempts.  Counting it would also refuse this grid on every run
#   for a permanent and correct reason, and a verdict that is always red is a verdict nobody reads.
#   ⭐ That refusal is this angle's honest finding, not its failure: one iteration is below gprolog's
#   resolution BY CONSTRUCTION, which is exactly why angles 1 and 2 loop N times before dividing.
#
# Only programs whose 4-way CORRECTNESS is consensus-green are timed; a FAIL in any engine prints SKIP
# for that row (timing wrong answers is meaningless).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/prolog/bench}"; T="${TIMEOUT:-60}"; N="${RUNS:-3}"
PRO="${PROLOG_DIR:-$S4E/corpus/benchmarks/prolog}"
GEN="${GEN:-$HERE/bench_prolog_wrap.sh}"
FLOOR_TICKS="${FLOOR_TICKS:-10}"
# THE SCRIP ARMS RUN AT EACH KERNEL'S DECLARED HEAP AND STACK (lib_declared_arena.sh's -d<kb>k -s<kb>k, after --run and at the head of
#   the mode-4 binary's argv; RULES.md clause 8 (g), CEO-1353). Until 2026-10-01 this line was ulimit -s unlimited and SCRIP got
#   nothing, so tak (declared 65536 KB) failed the pre-flight at the 4 MB default and its row read SKIP. MEASURED 2026-10-01 at
#   c1c899df3: all 23 kernels read the same on gprolog, swipl, m3 and m4 at the shell's soft 8 MB stack and at unlimited.
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot load lib_declared_arena.sh -- the ONE reader of a program's declared stack and heap sidecars (CEO-1281)"; exit 2; }
declare -a DECL_SW=()
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE libscrip_rt.so not built"; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSED-TO-GRADE bench corpus missing: $B"; exit 2; }
gprolog_bin >/dev/null || exit 2
command -v swipl   >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE swipl absent"; exit 2; }
[ -x "$GEN" ] || { echo "⛔ REFUSED-TO-GRADE wrapper generator missing: $GEN -- the wrapped form is generated, never checked in (CEO-567)"; exit 2; }
# ⛔ A rival that cannot load its clock is not a rival that disagreed: REFUSE, never a plausible SKIP.
[ -f "$PRO/prelude_gplc.pl" ] && [ -f "$PRO/prelude_swipl.pl" ] || { echo "⛔ REFUSED-TO-GRADE rival preludes missing under $PRO (prelude_gplc.pl / prelude_swipl.pl) -- the generator inlines them into the wrapped form"; exit 2; }
# ⛔ THE ONE AUTHORITY FOR THE LOAD STAMP AND THE GRID VERDICT (s266, CEO-697): a harness that cannot
#   load it REFUSES rather than inventing its own format or its own load line.
. "$HERE/lib_perf_fmt.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot load lib_perf_fmt.sh -- the ONE authority for the load stamp and the whole-grid refusal"; exit 2; }
# ⛔ THE ONE loop_check, shared with angles 1 and 2: a rule with two copies proves the copies agree, never that either is right.
. "$HERE/lib_prolog_bench.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot source lib_prolog_bench.sh -- the ONE loop-output check"; exit 2; }
WRAP="$ROOT/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED-TO-GRADE: bench_rusage failed to build -- basis (B) has no external instrument"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
now_ms() { echo $(( $(date +%s%N) / 1000000 )); }
# median_ms <cmd...> : run N times, print median wall ms (captures stdout to $W/last.out)
median_ms() {
  local times=() t0 t1 i
  for i in $(seq 1 "$N"); do
    t0=$(now_ms); (cd "$W" && timeout -k 5 "$T" "$@" </dev/null >"$W/last.out" 2>/dev/null); t1=$(now_ms)
    times+=( $((t1 - t0)) )
  done
  printf '%s\n' "${times[@]}" | sort -n | awk -v n="$N" 'NR==int((n+1)/2){print; exit}'
}
# tick_us <engine> -- the resolution of THAT engine's own wall clock, per its prelude's stated floor.
#   gnu: real_time/1 x 1000, quantized to 1000 us.  swi: get_time/1, a float epoch, genuinely sub-ms.
#   m3/m4r: SCRIP's wall_us/1 builtin, CLOCK_MONOTONIC, genuinely sub-ms.
tick_us() { case "$1" in gnu) echo 1000 ;; *) echo 1 ;; esac; }
# basis1 <eng> <wrapped.pl> <expected> -- ONE bench_rusage-wrapped run of the WRAPPED form.
#   echoes "<elapsed_us> <work_us>" or "- - <REASON>".
basis1() {
  local eng="$1" pl="$2" exp="$3" rl xc r elns work
  case "$eng" in
    gnu) "$WRAP" timeout -k 5 "$T" "$(gprolog_bin)" --consult-file "$pl" --query-goal halt >"$W/b.out" 2>"$W/b.err" </dev/null ;;
    swi) "$WRAP" timeout -k 5 "$T" swipl -q -g halt "$pl" >"$W/b.out" 2>"$W/b.err" </dev/null ;;
    m3)  "$WRAP" timeout -k 5 "$T" "$SCRIP" --run "${DECL_SW[@]}" "$pl" >"$W/b.out" 2>"$W/b.err" </dev/null ;;
    m4r) "$WRAP" timeout -k 5 "$T" "$W/wrapped.bin" "${DECL_SW[@]}" >"$W/b.out" 2>"$W/b.err" </dev/null ;;
  esac
  rl=$(grep '^BENCH_RUSAGE:' "$W/b.err" 2>/dev/null | tail -1)
  [ -n "$rl" ] || { echo "- - DNF"; return; }
  # ⛔ THE exit= FIELD IS THE ONLY RELIABLE CRASH SIGNAL -- NOT stderr TEXT (angle 2's finding, carried
  #   here): a segfaulting child still prints a well-formed BENCH_RUSAGE line, with the truth in exit=.
  xc=$(echo "$rl" | grep -oE 'exit=[0-9-]+' | cut -d= -f2)
  case "$xc" in ''|*[!0-9]*) echo "- - CRASH(exit=${xc:-?})"; return ;; esac
  [ "$xc" -ge 128 ] && { echo "- - CRASH(signal $((xc-128)))"; return; }
  [ "$xc" -ne 0 ] && { echo "- - NONZERO($xc)"; return; }
  # ⛔ GRADED, NOT ASSUMED: --mode=single's stdout is the kernel's real answer, so the very run that is
  #   being timed is also the run that is graded against the oracle-cut .ref (N=1 copy).
  r=$(loop_check "$eng" "$W/b.out" 1 "$exp") || { echo "- - $r"; return; }
  elns=$(echo "$rl" | grep -oE 'elapsed_ns=[0-9]+' | cut -d= -f2)
  work=$(grep -oE 'work_us=[0-9]+' "$W/b.err" 2>/dev/null | tail -1 | cut -d= -f2)
  echo "$(( ${elns:-0} / 1000 )) ${work:--}"
}
# basis_median <eng> <wrapped.pl> <expected> -- RUNS runs, print the MEDIAN-BY-ELAPSED run's own pair.
#   ⛔ One process's pair, never two medians -- see the header.
basis_median() {
  local eng="$1" pl="$2" exp="$3" i res lines=()
  for i in $(seq 1 "$N"); do
    res=$(basis1 "$eng" "$pl" "$exp")
    case "$res" in "- - "*) echo "$res"; return ;; esac
    lines+=( "$res" )
  done
  printf '%s\n' "${lines[@]}" | sort -n -k1,1 | awk -v n="$N" 'NR==int((n+1)/2){print; exit}'
}
# ⛔ CEO-697: A COST WITHOUT THE LOAD IT RAN UNDER IS NOT A COST, and perf_grid_begin welds the load to
#   the shared-axes line so this harness CANNOT print a duration without it.
perf_grid_begin "Prolog kernels, angle 3 process wrapper · (A) totals = wall ms median of $N over the PRISTINE kernel · (B) work/overhead = us over the GENERATED wrapped form · RT_OPT=-O0"
echo
echo "(A) PROCESS TOTALS (wall ms, median of $N, PRISTINE kernel, single-shot -- startup-dominated by design)"
printf "%-20s %8s %8s %8s %8s %8s\n" BENCH GNU_ms SWI_ms m3_ms m4r_ms m4c_ms
tot_ok=0; tot_skip=0
declare -A BWORK=(); declare -A BOVH=(); declare -A BEL=(); basis_rows=()
for pl in "$B"/*.pl; do
  s=$(basename "${pl%.pl}"); exp="${pl%.pl}.ref"
  [ -f "$exp" ] || continue
  want=$(cat "$exp")
  DECL_SW=(); dw=$(declared_switches_beside "$pl") || { echo "⛔ REFUSED-TO-GRADE: $s: a .stack or .heap sidecar the reader refuses (it said why above)"; exit 2; }
  [ -n "$dw" ] && read -r -a DECL_SW <<<"$dw"; undeclared_beside_named "$pl" || true
  # correctness pre-flight (one run per engine); any FAIL => SKIP row
  go=$(cd "$W" && timeout -k 5 "$T" "$(gprolog_bin)" --consult-file "$pl" --query-goal halt 2>/dev/null </dev/null | gnu_filter)
  so=$(cd "$W" && timeout -k 5 "$T" swipl -q -g halt "$pl" 2>/dev/null </dev/null | head -200)
  m3o=$(cd "$W" && timeout -k 5 "$T" "$SCRIP" --run "${DECL_SW[@]}" "$pl" </dev/null 2>/dev/null | head -200)
  if [ "$go" != "$want" ] || [ "$so" != "$want" ] || [ "$m3o" != "$want" ]; then
    printf "%-20s %8s %8s %8s %8s %8s\n" "$s" SKIP SKIP SKIP SKIP SKIP; tot_skip=$((tot_skip+1)); continue
  fi
  # m4: compile+link once (timed), then time binary alone
  c0=$(now_ms)
  asm=$(cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile --target=x86 "$pl" </dev/null 2>/dev/null)
  printf '%s\n' "$asm" > "$W/$s.s"
  (cd "$W" && as --64 -o "$s.o" "$s.s" 2>/dev/null) \
    && gcc -no-pie -o "$W/$s.bin" "$W/$s.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null
  c1=$(now_ms); m4c=$((c1 - c0))
  m4o=$(cd "$W" && timeout -k 5 "$T" ./$s.bin "${DECL_SW[@]}" </dev/null 2>/dev/null | head -200)
  if [ "$m4o" != "$want" ]; then
    printf "%-20s %8s %8s %8s %8s %8s\n" "$s" SKIP SKIP SKIP SKIP SKIP; tot_skip=$((tot_skip+1)); continue
  fi
  gnu=$(median_ms "$(gprolog_bin)" --consult-file "$pl" --query-goal halt)
  swi=$(median_ms swipl -q -g halt "$pl")
  m3=$(median_ms "$SCRIP" --run "${DECL_SW[@]}" "$pl")
  m4r=$(median_ms ./$s.bin "${DECL_SW[@]}")
  printf "%-20s %8s %8s %8s %8s %8s\n" "$s" "$gnu" "$swi" "$m3" "$m4r" "$m4c"
  tot_ok=$((tot_ok+1))
  # ---- basis (B): the SAME kernel through the generator, measured from outside and from inside ----
  builtbin=no
  for eng in gnu swi m3 m4r; do
    case "$eng" in gnu) ge=gnu ;; swi) ge=swi ;; *) ge=scrip ;; esac
    gpl="$W/gen.$s.$ge.pl"
    if [ ! -s "$gpl" ] && ! "$GEN" "$pl" --mode=single --engine="$ge" -o "$gpl" >/dev/null 2>"$W/gen.err"; then
      BWORK["$s:$eng"]="GEN-REFUSED"; BOVH["$s:$eng"]="GEN-REFUSED"; BEL["$s:$eng"]="GEN-REFUSED"
      perf_dark_cell "$s/$eng: wrapper generator refused ($(head -1 "$W/gen.err" 2>/dev/null | cut -c1-48))"; continue
    fi
    if [ "$eng" = m4r ] && [ "$builtbin" = no ]; then
      builtbin=fail
      if (cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile --target=x86 "$gpl" </dev/null >"$W/wrapped.s" 2>/dev/null) && [ -s "$W/wrapped.s" ] \
         && (cd "$W" && as --64 -o "$W/wrapped.o" "$W/wrapped.s" 2>/dev/null) \
         && gcc -no-pie -o "$W/wrapped.bin" "$W/wrapped.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null; then builtbin=ok; fi
    fi
    if [ "$eng" = m4r ] && [ "$builtbin" != ok ]; then
      BWORK["$s:$eng"]="BUILD-ERR"; BOVH["$s:$eng"]="BUILD-ERR"; BEL["$s:$eng"]="BUILD-ERR"
      perf_dark_cell "$s/m4r: the wrapped form did not compile+link"; continue
    fi
    res=$(basis_median "$eng" "$gpl" "$exp"); el=$(awk '{print $1}' <<<"$res"); wk=$(awk '{print $2}' <<<"$res")
    if [ "$el" = "-" ]; then
      why=$(cut -d' ' -f3- <<<"$res"); BWORK["$s:$eng"]="NA"; BOVH["$s:$eng"]="NA"; BEL["$s:$eng"]="NA"
      perf_dark_cell "$s/$eng: $why"; continue
    fi
    BEL["$s:$eng"]="$el"
    # ⛔ A MISSING work_us IS PRINTED AS DARK, NEVER BLANK AND NEVER ZERO (CEO-676, dark-is-worse-than-red).
    case "$wk" in
      ''|-|*[!0-9]*) BWORK["$s:$eng"]="DARK"; BOVH["$s:$eng"]="DARK"
                     perf_dark_cell "$s/$eng: ran and graded, but its bracket reported no work_us" ;;
      *) if [ "$wk" -lt $(( $(tick_us "$eng") * FLOOR_TICKS )) ]; then
           # ⛔ UNDER ITS OWN CLOCK'S FLOOR: name the reading, publish no number.  See the header.
           # ⭐ NOT A DARK CELL and it does not bump the count (lib_perf_fmt.sh THE DARK-CELL LAW): a
           # subject the caller KNOWS is below its instrument and says so in its own words, showing what
           # it read, is a MEASUREMENT. The reader is told the truth; nothing is fabricated and nothing
           # is hidden. Bumping here would also make this grid refuse on EVERY run for a known, correct,
           # permanent reason -- a verdict that is always red is not read, which is how a real dark cell
           # would then travel unnoticed beside it.
           BWORK["$s:$eng"]="TICK-FLOOR($wk)"; BOVH["$s:$eng"]="TICK-FLOOR"
         else
           BWORK["$s:$eng"]="$wk"; BOVH["$s:$eng"]=$(( el - wk ))
         fi ;;
    esac
  done
  basis_rows+=("$s")
done
echo
echo "(A) RESULT: timed=$tot_ok skipped=$tot_skip   (SKIP = the 4-way single-shot answers are not consensus-green; timing a wrong answer is meaningless)"
echo
echo "(B) THE TWO-NUMBER WORK/OVERHEAD BASIS -- over the GENERATED wrapped form ($(basename "$GEN") --mode=single),"
echo "    external instrument tools/bench_rusage, median-by-elapsed of $N runs, BOTH cells from that one run."
echo "    ⛔ These rows are NOT (A)'s rows minus anything: (A) runs the pristine kernel, (B) runs the wrapped"
echo "    form (which on gnu/swi also inlines that engine's prelude). Two programs, two tables, no subtraction."
echo
echo "EXTERNAL ELAPSED (us) -- tools/bench_rusage, CLOCK_MONOTONIC, the whole process"
printf "%-20s %14s %14s %14s %14s\n" BENCHMARK gnu swi m3 m4r
printf "%-20s %14s %14s %14s %14s\n" "--------------------" "--------------" "--------------" "--------------" "--------------"
for k in "${basis_rows[@]}"; do
  printf "%-20s %14s %14s %14s %14s\n" "$k" "${BEL[$k:gnu]:-DARK}" "${BEL[$k:swi]:-DARK}" "${BEL[$k:m3]:-DARK}" "${BEL[$k:m4r]:-DARK}"
done
echo
echo "SELF-MEASURED WORK (us) -- read from INSIDE the generated bracket, wall clock (CLOCK_MONOTONIC),"
echo "  ONE iteration (--mode=single), so it is directly comparable across engines with no N to divide out."
echo "  ⛔ TICK-FLOOR(n) = the engine's own clock cannot resolve one iteration of this kernel: gprolog's"
echo "  wall_us is real_time/1 x 1000, a 1 ms tick wearing microsecond units (prelude_gplc.pl says so), so"
echo "  a cell under $FLOOR_TICKS ticks prints what it read and no number -- a stated measurement, not a dark"
echo "  cell, so it does not make the grid refuse. That is this angle's honest finding, not its failure:"
echo "  one iteration is below gprolog's resolution BY CONSTRUCTION, which is why angles 1 and 2 loop first."
printf "%-20s %14s %14s %14s %14s\n" BENCHMARK gnu swi m3 m4r
printf "%-20s %14s %14s %14s %14s\n" "--------------------" "--------------" "--------------" "--------------" "--------------"
for k in "${basis_rows[@]}"; do
  printf "%-20s %14s %14s %14s %14s\n" "$k" "${BWORK[$k:gnu]:-DARK}" "${BWORK[$k:swi]:-DARK}" "${BWORK[$k:m3]:-DARK}" "${BWORK[$k:m4r]:-DARK}"
done
echo
echo "OVERHEAD (us) = external elapsed MINUS self-measured work -- startup + consult/codegen + teardown,"
echo "  which the kernel never did. On this single-shot angle it is most of the wall clock, and THAT is"
echo "  what angle 3 exists to measure: angles 1 and 2 divide it away, this one prints it."
echo "  ⛔ wall minus wall, never CPU minus wall -- the two are different instruments and their difference"
echo "  is not an overhead; on a loaded box it goes negative, which is the tell."
echo "  DARK = the engine ran but its bracket reported no work_us; it is named, never left blank (CEO-676)."
printf "%-20s %14s %14s %14s %14s\n" BENCHMARK gnu swi m3 m4r
printf "%-20s %14s %14s %14s %14s\n" "--------------------" "--------------" "--------------" "--------------" "--------------"
for k in "${basis_rows[@]}"; do
  printf "%-20s %14s %14s %14s %14s\n" "$k" "${BOVH[$k:gnu]:-DARK}" "${BOVH[$k:swi]:-DARK}" "${BOVH[$k:m3]:-DARK}" "${BOVH[$k:m4r]:-DARK}"
done
echo
echo "ENGINES: GNU=$("$(gprolog_bin)" --version </dev/null 2>&1 | head -1)"
echo "         SWI=$(swipl --version </dev/null 2>&1 | head -1)"
echo "METHOD: (A) wall-clock median of $N; GNU=consult mode; SWI=script mode; m3=--run end-to-end"
echo "        (in-process codegen+exec); m4r=precompiled binary exec only; m4c=compile+as+gcc."
echo "        (B) generated --mode=single wrapper per engine, median-by-elapsed of $N under tools/bench_rusage."
# ⛔ THE GRID VERDICT IS PRINTED, AND IT IS NOT SWALLOWED.  perf_grid_end says how many cells could not
#   measure their subject at all -- a run that crashed or did not finish, a bracket that reported
#   nothing, a wrapped form that would not build, a generator that refused.  TICK-FLOOR is NOT among
#   them (see above), so on a healthy tree this closes rc=0 and its firing means something real broke.
perf_grid_end; grid_rc=$?
[ "$grid_rc" -eq 0 ] || echo "  (the refusal above is about basis (B) only; table (A) is a TOTAL basis and carries no self-measured cell)"
# ⛔⭐ THE EXIT STATUS IS THE GRID VERDICT, AND IT IS NOT SWALLOWED.  rc=2 carries this tree's standing
#   meaning -- REFUSED TO GRADE, this run produced an INCOMPLETE grid, do not quote it -- and it can
#   actually fire: MEASURED on SCRIP 13214eba9 over all 22 timed kernels x 4 engines, 0 dark cells, so
#   rc=0 is the healthy reading rather than a shape that never fails.  Proven fail-once through the real
#   harness by GEN overrides (a generator that refuses; a generator that emits no bracket): 8 dark cells,
#   named on stderr, grid REFUSES, rc=2.
#   ⛔ IT IS DELIBERATELY NOT (A)'s SKIP COUNT.  `tak` SKIPs on this tree today for a reason that belongs
#   to another lane; folding that in would hand the next seat a permanent red whose cause is not in this
#   file, and a verdict that is always red is a verdict nobody reads.  The SKIP count is printed loudly
#   above instead.  One meaning per exit code -- rc=2 here is always "a cell could not measure its subject".
exit "$grid_rc"
