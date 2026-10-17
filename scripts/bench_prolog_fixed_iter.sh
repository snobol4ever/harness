#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_prolog_fixed_iter.sh -- ANGLE 2 of the Prolog three-angle triangulation (row bench-rivals-prolog,
# mirroring bench_snobol4_fixed_iter.sh / ARCH-BENCH-CAMPAIGN-README-TABLES.md THREE-ANGLE TRIANGULATION).
#
# Run EXACTLY N iterations per kernel (N fixed, COMMITTED, never a wall-clock deadline) and report
# throughput (iterations/s) for gnu (gprolog) / swi (swipl) / m3 / m4. This is the mirror of
# test_bench_prolog_timed.sh (angle 1: LIVE doubling search each run). Angle 2 instead reads N from the
# committed table corpus/benchmarks/prolog/fixed-iter-n.tsv and GENERATES the counted wrapper around the
# pristine kernel at run time -- so N here is HISTORICAL data, not derived live, which is the independence
# property the cross-proof needs (angle 1 = live search this run; angle 2 = pre-committed N).
#
# ⭐⛔ THE WRAPPER IS GENERATED, NEVER CHECKED IN (CEO-567, RULES.md:321; hq_P 2026-09-13, row
# bench-kernels-are-not-pristine-and-carry-no-refs-ceo-567-conversion). This arm used to EXECUTE
# corpus/benchmarks/prolog/vanroy/<k>.pl -- 21 checked-in files each carrying a frozen `main :- l__(N).`,
# i.e. THE ITERATION COUNT LIVING INSIDE THE ARTIFACT UNDER MEASUREMENT, which is the thing CEO-567
# forbids. Worse, those 21 were generated from the PRE-conversion bench/ sources, so each wrapped an old
# self-timing main/0: MEASURED on SCRIP 5b17c350f / corpus d97c5fe87, the last vanroy board read
# ok=0 bad=21 with EVERY m3 and m4 cell NA -- 13 of them LOOP-OUTPUT-MISMATCH(lines=0/N) because
# existence_error(wall_us/1) killed the answer and exited 0, and gnu itself failed on ham/queens_8/queens.
# The directory was a generated artifact that had drifted away from the sources it was generated from,
# and nothing reported the drift because the rival columns kept printing real numbers.
# Now: N comes from the TSV, the source is bench/<k>.pl VERBATIM, and ../harness/scripts/bench_prolog_wrap.sh builds
# the counted form per engine into a temp file. One authority for the wrapper shape, none of it on disk.
#
# ⛔ CORRECTNESS IS NOT RE-VERIFIED HERE, but it is no longer taken on trust either: loop_check()
# compares this run's stdout byte-for-byte against N copies of bench/<k>.ref (the oracle-cut ref), so
# a kernel whose loop did not loop N times reports LOOP-OUTPUT-MISMATCH and never a rate. The single-shot
# answer check remains angle 1's job -- one authority, not two copies of the correctness check.
#
# External CPU time via tools/bench_rusage (elapsed_ns + user_us + sys_us), same instrument angle 3
# (disk telemetry) and the SNOBOL4 triangulator both use -- never self-timing (row
# bench-external-cpu-and-elapsed-clock's law, applied here too).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/prolog/bench}"
PRO="${PROLOG_DIR:-$S4E/corpus/benchmarks/prolog}"
NTSV="${NTSV:-$PRO/fixed-iter-n.tsv}"
GEN="${GEN:-$HERE/bench_prolog_wrap.sh}"
T="${TIMEOUT:-60}"
# KERNELS, if set, restricts the run to this space-separated allowlist (basenames, no .pl) instead of
# every row of $NTSV. Re-timing a kernel currently known to crash wastes wall-clock for no citable
# number. The triangulator passes this explicitly from angle 1's OWN fresh non-SKIP list each run, so the
# allowlist is never hand-maintained or stale itself. Unset (bare use) runs every row of the table.
KERNELS="${KERNELS:-}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE libscrip_rt.so not built"; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSED-TO-GRADE kernel dir missing: $B"; exit 2; }
[ -s "$NTSV" ] || { echo "⛔ REFUSED-TO-GRADE committed-N table missing or empty: $NTSV -- angle 2 has no historical N and would be a second copy of angle 1"; exit 2; }
[ -x "$GEN" ] || { echo "⛔ REFUSED-TO-GRADE wrapper generator missing: $GEN -- the counted form is generated, never checked in (CEO-567)"; exit 2; }
gprolog_bin >/dev/null || exit 2
command -v swipl   >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE swipl absent"; exit 2; }
gplc_bin >/dev/null || exit 2
# ⛔ THE RIVAL PRELUDES ARE PART OF THE RIVAL INVOCATION, NOT AN OPTION (hq_P 2026-09-02, row prolog-instruments-and-baseline-standup).
# The generated wrapper calls wall_us/1 + wall_ms/1, which gprolog and swipl do not have; prelude_gplc.pl / prelude_swipl.pl supply
# them. MEASURED before that line existed: every bracketed kernel failed the rival correctness gate with existence_error(wall_us/1),
# so its whole row read SKIP and the triangulation TSV published UNPROVEN for gnu AND swi -- an instrument defect printed in the
# vocabulary of a kernel finding (the 2026-09-02 "12 cells UNPROVEN in 6 s" null). ⭐ THE PRELUDE IS NOW INLINED BY THE GENERATOR
# (bench_prolog_wrap.sh cats it above the verbatim kernel) rather than consulted as a second file, so each engine runs ONE
# self-contained program and the kernel text inside it stays byte-identical across engines -- the kernel is the thing being compared.
# Consulting it again here would redefine wall_us/1 under the generator's own definition and grade a program nobody wrote.
# Still REFUSE when a prelude is missing, never a plausible SKIP: a rival that cannot load its clock is not a rival that disagreed.
[ -f "$PRO/prelude_gplc.pl" ] && [ -f "$PRO/prelude_swipl.pl" ] || { echo "⛔ REFUSED-TO-GRADE rival preludes missing under $PRO (prelude_gplc.pl / prelude_swipl.pl)"; exit 2; }
. "$HERE/lib_prolog_bench.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE (rc=2): cannot source lib_prolog_bench.sh -- the ONE loop-output check"; exit 2; }
. "$HERE/lib_perf_fmt.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE (rc=2): cannot load lib_perf_fmt.sh -- the ONE authority for the load stamp and the whole-grid refusal (s266/CEO-697)"; exit 2; }
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot load lib_declared_arena.sh -- the ONE reader of a program's declared stack and heap sidecars (CEO-1281)"; exit 2; }
# ⛔ THE SCRIP ARMS RUN UNDER THE KERNEL'S OWN DECLARATION (ceo CEO-1281, 2026-09-26): the <k>.heap / <k>.stack sidecars as SPITBOL's -d<kb>k -s<kb>k
#   switches on every m3 and m4 command line (lib_declared_arena.sh, the suite runner's reader; CEO-1225; tak: -s65536k).
declare -a DECL_SW=(); declare -A DECLW=()
WRAP="$ROOT/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED: bench_rusage failed to build" >&2; exit 2; }
# ⛔ timeout -k 5 EVERYWHERE (hq_P 2026-09-02, measured): swipl ignores timeout's SIGTERM -- angle 2 sat 648 s on vanroy/queens.pl
# under `timeout 60` with the whole triangulation behind it. A bound that the bounded process can decline is not a bound; -k makes
# the kill unconditional five seconds after the deadline, and the run then reads CRASH(signal 9), never a rate (the exit= gate).
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# No ulimit here: SCRIP's stack is DECL_SW's -s, and the rivals' own stacks are theirs. Until 2026-10-01 this line was ulimit -s unlimited.
#   MEASURED 2026-10-01 at c1c899df3: all 23 kernels read the same on gprolog, swipl, m3 and m4 at the shell's soft 8 MB stack and at
#   unlimited, and the generated loop is failure-driven (between/3 then fail), so N never deepens a stack (RULES.md clause 8 (g), CEO-1353).

# ⛔ THE TABLE IS THE ONLY SOURCE OF N HERE. It is read once, up front, so an unreadable or orphaned row
# REFUSES before a single engine is launched rather than printing a board that is quietly smaller.
# ⭐ TWO COUNT COLUMNS SINCE CEO-1281 (2026-09-26), THE PASCAL SCALE.tsv PRECEDENT: N is the SCRIP count (m3, m4) and N_rival the count for
#   gnu, gplc and swi, defaulting to N when the column is empty. gplc (GNU Prolog compiled native) runs the fast kernels 20-80x faster than
#   mode 3, and its clock ticks at 1 ms, so one shared count either starves the rival bracket (cal at 524288: 63 ms on gplc, 1.15x between
#   its angles) or costs mode 3 a quarter of a minute per kernel. The per-iteration figures below divide each engine by ITS count.
declare -A NCOMMIT=(); declare -A NRIVAL=(); order=()
while IFS=$'\t' read -r k n nr; do
  case "$k" in ''|'#'*|kernel) continue ;; esac
  case "$n" in ''|*[!0-9]*) echo "⛔ REFUSED-TO-GRADE: $NTSV row '$k' has a non-numeric N '$n'"; exit 2 ;; esac
  case "$nr" in '') nr="$n" ;; *[!0-9]*) echo "⛔ REFUSED-TO-GRADE: $NTSV row '$k' has a non-numeric N_rival '$nr'"; exit 2 ;; esac
  NRIVAL["$k"]="$nr"
  [ -f "$B/$k.pl" ] || { echo "⛔ REFUSED-TO-GRADE: $NTSV names '$k' but $B/$k.pl does not exist -- an orphan denominator entry is a lie, not a smaller board"; exit 2; }
  NCOMMIT["$k"]="$n"; order+=("$k")
done < "$NTSV"
[ "${#order[@]}" -gt 0 ] || { echo "⛔ REFUSED-TO-GRADE: $NTSV carries zero kernel rows"; exit 2; }
rate() { awk -v n="$1" -v us="$2" 'BEGIN{ if (us+0>0) printf "%.4f", n/(us/1e6); else print "NA" }'; }

# one bench_rusage-wrapped run; echoes "cpu_us nivcsw" or "- -" + reason on crash/DNF/missing rusage line
run1() {
  local eng="$1" pl="$2" n="${3:-}" exp="${4:-}" out rl user sys nivcsw r
  case "$eng" in
    gnu) out=$("$WRAP" timeout -k 5 "$T" "$(gprolog_bin)" --consult-file "$pl" --query-goal halt >"$W/o.$$" 2>"$W/e.$$") ;;
    # ⭐ gplc -- GNU Prolog's NATIVE compiler (Prolog -> WAM -> mini-assembly -> x86-64, linked; ceo CEO-1281 on Lon's question of 2026-09-26,
    #   "Is GNU Prolog a true compiler?"): the gnu arm above is gprolog's BYTE-CODE WAM interpreter (a consulted file never becomes native
    #   code), so until this arm the grid compared SCRIP with two interpreters. Same generated program as gnu (--engine=gnu inlines the
    #   real_time/1 prelude), compiled here with --no-top-level so the binary exits after its initialization goals and prints no banner.
    #   MEASURED at the arm's birth: nrev at 65536 iterations, gplc 371 ms of work against 911-930 ms consulted -- about 2.5x.
    gplc) local gb="$W/$$.gplc"; rm -f "$gb"
         if ! (cd "$W" && timeout -k 5 "$T" "$(gplc_bin)" --no-top-level -o "$gb" "$pl" >/dev/null 2>&1) || [ ! -x "$gb" ]; then echo "- - GPLC-BUILD-ERR"; return; fi
         out=$("$WRAP" timeout -k 5 "$T" "$gb" >"$W/o.$$" 2>"$W/e.$$") ;;
    swi) out=$("$WRAP" timeout -k 5 "$T" swipl -q -g halt "$pl" >"$W/o.$$" 2>"$W/e.$$") ;;
    m3)  out=$("$WRAP" timeout -k 5 "$T" "$SCRIP" --run "${DECL_SW[@]}" "$pl" >"$W/o.$$" 2>"$W/e.$$") ;;
    m4)  local s="$W/$$.s" b="$W/$$.bin"
         if ! (cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile --target=x86 "$pl" </dev/null >"$s" 2>/dev/null) || [ ! -s "$s" ]; then
           echo "- - BUILD-ERR"; return; fi
         if ! (as --64 -o "$W/$$.o" "$s" 2>/dev/null && gcc -no-pie -o "$b" "$W/$$.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null); then
           echo "- - LINKFAIL"; return; fi
         out=$("$WRAP" timeout -k 5 "$T" "$b" "${DECL_SW[@]}" >"$W/o.$$" 2>"$W/e.$$") ;;
  esac
  rl=$(grep '^BENCH_RUSAGE:' "$W/e.$$" 2>/dev/null | tail -1)
  if [ -z "$rl" ]; then echo "- - DNF"; return; fi
  # ⛔ THE exit= FIELD IS THE ONLY RELIABLE CRASH SIGNAL -- NOT stderr TEXT (found live, this row: a
  # segfaulting child still prints a well-formed BENCH_RUSAGE line with exit=139, and the shell's own
  # "Segmentation fault" job-control notice does NOT reliably land in a redirected/captured stderr file
  # the way `timeout`'s own "dumped core" message does -- grepping for crash TEXT silently passed a
  # segfaulting run through as a real (implausibly fast) measurement. bench_rusage.c always emits this
  # line and always encodes the true outcome in exit= (128+signal on a signal death), so that field --
  # never text-sniffing -- is what gates whether a cpu_us number is trusted.
  local xc; xc=$(echo "$rl" | grep -oE 'exit=[0-9-]+' | cut -d= -f2)
  case "$xc" in ''|*[!0-9]*) echo "- - CRASH(exit=${xc:-?})"; return ;; esac
  [ "$xc" -ge 128 ] && { echo "- - CRASH(signal $((xc-128)))"; return; }
  [ "$xc" -ne 0 ] && { echo "- - NONZERO($xc)"; return; }
  r=$(loop_check "$eng" "$W/o.$$" "$n" "$exp") || { echo "- - $r"; return; }
  user=$(echo "$rl" | grep -oE 'user_us=[0-9]+' | cut -d= -f2); sys=$(echo "$rl" | grep -oE 'sys_us=[0-9]+' | cut -d= -f2)
  nivcsw=$(echo "$rl" | grep -oE 'nivcsw=[0-9]+' | cut -d= -f2)
  # ⭐ THE TWO-NUMBER WORK/OVERHEAD BASIS (CEO-567 DONE-WHEN: "the process wrapper's numbers printed
  #   beside the self-measured ones").  WORK is what the generated bracket measured from INSIDE;
  #   ELAPSED is what tools/bench_rusage measured from OUTSIDE; OVERHEAD is the difference, and it is
  #   the startup + load + teardown the kernel never did.
  # ⛔⛔ THE SUBTRACTION IS WALL MINUS WALL, AND THAT IS NOT A DETAIL -- IT IS THE APPLES-TO-APPLES LAW.
  #   bench_rusage reports BOTH elapsed_ns (CLOCK_MONOTONIC) and user_us+sys_us (CPU), and the rate
  #   columns above deliberately use the CPU pair.  But wall_us/1 inside the bracket is CLOCK_MONOTONIC
  #   (src/runtime/unification.c:618, VERIFIED for this row), so `user+sys - work` would subtract a WALL
  #   number from a CPU one and publish the difference of two different instruments as an overhead.
  #   On a loaded box that difference can even go NEGATIVE, which is the tell.  elapsed_us is therefore
  #   carried separately from cpu_us for exactly this one purpose.  RULES.md: never mix instruments.
  local elns work
  elns=$(echo "$rl" | grep -oE 'elapsed_ns=[0-9]+' | cut -d= -f2)
  work=$(grep -oE 'work_us=[0-9]+' "$W/e.$$" 2>/dev/null | tail -1 | cut -d= -f2)
  echo "$(( ${user:-0} + ${sys:-0} )) ${nivcsw:-0} $(( ${elns:-0} / 1000 )) ${work:--}"
}

echo "FIXED-ITERATION PROLOG BENCHMARKS -- angle 2: N fixed per kernel (committed in $NTSV), external cpu time measured"
echo "kernels: $B (pristine, verbatim)   wrapper: GENERATED per engine by $(basename "$GEN") --mode=iter (never checked in, CEO-567)"
echo "engines: gnu gplc swi m3 m4 (gnu = "$(gprolog_bin)" --consult-file, the byte-code WAM; gplc = GNU Prolog compiled native)   external instrument: tools/bench_rusage (user+sys cpu time)"
# ⛔⭐ THE LOAD STAMP IS THE PRINTER'S JOB AND IT BELONGS ABOVE THE NUMBERS, NOT UNDER THEM (hq_P
#   2026-09-13).  This harness hand-rolled its own LOAD line and printed it AFTER the last grid, so a
#   reader who pasted a grid -- which is what anyone pastes -- carried the numbers away and left the
#   load behind.  perf_grid_begin welds it to the shared-axes line the FACT RULE requires, at the top,
#   where it cannot be separated from what it qualifies.  Two runs of this angle on one tree have been
#   measured differing by up to 2.15x, so the stamp is not decoration.
perf_grid_begin "Prolog kernels vs gnu/swi -- angle 2, N committed per kernel in $(basename "$NTSV") · rate = iterations / CPU(user+sys) · WORK = self-measured wall inside the bracket · RT_OPT=-O0"
echo
printf "%-14s %10s %14s %14s %14s %14s %14s  %s\n" BENCHMARK N[/N_rival] gnu/s gplc/s swi/s m3/s m4/s check
printf "%-14s %10s %14s %14s %14s %14s %14s  %s\n" "--------------" "----------" "--------------" "--------------" "--------------" "--------------" "--------------" "-----"
tot_ok=0; tot_bad=0
declare -A BWORK=(); declare -A BOVH=(); basis_rows=()
for k in "${order[@]}"; do
  if [ -n "$KERNELS" ]; then case " $KERNELS " in *" $k "*) ;; *) continue ;; esac; fi
  N="${NCOMMIT[$k]}"; NR="${NRIVAL[$k]}"; pl="$B/$k.pl"
  DECL_SW=(); dw=$(declared_switches_beside "$pl") || { echo "⛔ REFUSED-TO-GRADE: $k: a .stack or .heap sidecar the reader refuses (it said why above) -- a program whose declaration cannot be read is not timed under the default it did not ask for"; exit 2; }
  [ -n "$dw" ] && { read -r -a DECL_SW <<<"$dw"; DECLW["$k"]="$dw"; }
  ckstat=ok; declare -A RATE=(); declare -A WORK=(); declare -A OVH=(); local_el=""; local_wk=""
  for eng in gnu gplc swi m3 m4; do
    # ⛔ --engine names WHO WILL RUN THE OUTPUT and changes only the PRELUDE, never the kernel; m3 and m4 are
    # both the SCRIP arm, which gets no prelude because SCRIP's Prolog has no wall clock at any spelling.
    case "$eng" in gnu|gplc) ge=gnu ;; swi) ge=swi ;; *) ge=scrip ;; esac
    case "$eng" in m3|m4) EN="$N" ;; *) EN="$NR" ;; esac   # the engine's own count (CEO-1281)
    gpl="$W/gen.$k.$ge.pl"
    if [ ! -s "$gpl" ]; then
      if ! "$GEN" "$B/$k.pl" --mode=iter --n="$EN" --engine="$ge" -o "$gpl" >/dev/null 2>"$W/gen.err"; then
        RATE[$eng]="NA"; perf_dark_cell "$k/$eng" "generator refused: $(head -1 "$W/gen.err" | cut -c1-48)"
        [ "$ckstat" = ok ] && ckstat="$eng:GEN-REFUSED($(head -1 "$W/gen.err" | cut -c1-48))"; continue
      fi
    fi
    res=$(run1 "$eng" "$gpl" "$EN" "$B/$k.ref"); cpu=$(awk '{print $1}' <<<"$res")
    if [ "$cpu" = "-" ]; then RATE[$eng]="NA"; WORK[$eng]="NA"; OVH[$eng]="NA"; reason=$(cut -d' ' -f3- <<<"$res")
      # ⛔ ONE BUMP PER UNMEASURED (kernel, engine) PAIR, not per printed cell: one failed run darkens
      #   the same measurement in the rate, work and overhead grids, and counting it three times would
      #   say three things went wrong when one did.
      perf_dark_cell "$k/$eng" "run produced no cpu time: $reason"
      [ "$ckstat" = ok ] && ckstat="$eng:$reason"
    else
      RATE[$eng]=$(rate "$EN" "$cpu")
      local_el=$(awk '{print $3}' <<<"$res"); local_wk=$(awk '{print $4}' <<<"$res")
      # ⛔ A MISSING work_us IS PRINTED AS DARK, NEVER AS A BLANK AND NEVER AS ZERO (CEO-676,
      #   dark-is-worse-than-red): an engine whose bracket did not report is a cell that could not
      #   measure its subject, and it must say so in its own voice rather than leave the column empty.
      case "$local_wk" in ''|-|*[!0-9]*) WORK[$eng]="DARK"; OVH[$eng]="DARK"
          perf_dark_cell "$k/$eng" "the generated bracket reported no work_us" ;;
        *) WORK[$eng]=$(awk -v w="$local_wk" -v n="$EN" 'BEGIN{printf "%.4f", (n>0)?w/n:0}'); OVH[$eng]=$(( local_el - local_wk )) ;; esac
    fi
  done
  [ "$ckstat" = ok ] && tot_ok=$((tot_ok+1)) || tot_bad=$((tot_bad+1))
  printf "%-14s %10s %14s %14s %14s %14s %14s  %s\n" "$k" "$([ "$N" = "$NR" ] && printf %s "$N" || printf %s/%s "$N" "$NR")" "${RATE[gnu]}" "${RATE[gplc]}" "${RATE[swi]}" "${RATE[m3]}" "${RATE[m4]}" "$ckstat"
  for eng in gnu gplc swi m3 m4; do BWORK["$k:$eng"]="${WORK[$eng]:-DARK}"; BOVH["$k:$eng"]="${OVH[$eng]:-DARK}"; done
  basis_rows+=("$k")
done
echo
echo "CHECK RESULT: ok=$tot_ok bad=$tot_bad   (bad = crash/DNF/build-fail on at least one engine this run; correctness itself is angle 1's job)"

# ⭐⭐ THE TWO-NUMBER WORK/OVERHEAD BASIS, PUBLISHED PER ENGINE -- the CEO-567 DONE-WHEN clause "the
#   process wrapper's numbers printed beside the self-measured ones".  Until 2026-09-13 the SCRIP
#   columns here could not exist at all: SCRIP's Prolog had no wall clock at any spelling, so the m3
#   and m4 arms had a TOTAL and no WORK, and a total carries startup and may never share a column with
#   a rival's self-measured work.  wall_us/1 and wall_ms/1 landing as real builtins (cto, 05317a5fb)
#   is what fills these two grids in.
echo
echo "SELF-MEASURED WORK PER ITERATION (us/iter) = work_us / the engine's own committed N -- read from INSIDE the generated bracket, wall clock"
echo "  (CLOCK_MONOTONIC). This is the number comparable across engines: it excludes process startup entirely and divides out each"
echo "  engine's count (N for m3/m4, N_rival for gnu/gplc/swi, the two columns of fixed-iter-n.tsv; CEO-1281 -- before it this block was raw"
echo "  work_us over ONE shared N). ⛔ gprolog's and gplc's wall_us is real_time/1 x 1000, a 1 ms tick: N_rival is sized so the bracket holds 200 ms or more."
printf "%-14s %14s %14s %14s %14s %14s\n" BENCHMARK gnu gplc swi m3 m4
printf "%-14s %14s %14s %14s %14s %14s\n" "--------------" "--------------" "--------------" "--------------" "--------------" "--------------"
for k in "${basis_rows[@]}"; do
  printf "%-14s %14s %14s %14s %14s %14s\n" "$k" "${BWORK[$k:gnu]}" "${BWORK[$k:gplc]}" "${BWORK[$k:swi]}" "${BWORK[$k:m3]}" "${BWORK[$k:m4]}"
done
echo
echo "OVERHEAD (us) = external elapsed (tools/bench_rusage, CLOCK_MONOTONIC) MINUS self-measured work"
echo "  ⛔ wall minus wall, never CPU minus wall -- the rate columns above use CPU and are a DIFFERENT"
echo "  instrument; subtracting across the two would publish the difference of two clocks as an overhead."
echo "  DARK = the engine ran but its bracket reported no work_us; it is named, never left blank (CEO-676)."
printf "%-14s %14s %14s %14s %14s %14s\n" BENCHMARK gnu gplc swi m3 m4
printf "%-14s %14s %14s %14s %14s %14s\n" "--------------" "--------------" "--------------" "--------------" "--------------" "--------------"
for k in "${basis_rows[@]}"; do
  printf "%-14s %14s %14s %14s %14s %14s\n" "$k" "${BOVH[$k:gnu]}" "${BOVH[$k:gplc]}" "${BOVH[$k:swi]}" "${BOVH[$k:m3]}" "${BOVH[$k:m4]}"
done
echo
echo "DECLARED SIDECARS carried as switches on the m3 and m4 command lines (lib_declared_arena.sh, the suite runner's reader; CEO-1281): ${#DECLW[@]} kernel(s)"
for k in "${!DECLW[@]}"; do echo "  $k: ${DECLW[$k]}"; done
echo
# ⛔⭐ tot_bad AND THE GRID VERDICT ARE NOT THE SAME BAR, WHICH IS WHY BOTH ARE HERE.  tot_bad counts a
#   ROW that had a crash/DNF on some engine; perf_grid_end counts every CELL that could not be measured,
#   including a work_us that never arrived on a row whose rate came back fine -- a hole tot_bad cannot
#   see, because the row is not "bad", it is INCOMPLETE.
perf_grid_end; grid_rc=$?
[ "$tot_bad" -eq 0 ] && [ "$grid_rc" -eq 0 ]
