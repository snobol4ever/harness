#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# test_bench_prolog_timed.sh -- ANGLE 1 of the Prolog three-angle triangulation (row bench-rivals-prolog,
# mirroring test_bench_snobol4_timed.sh / ARCH-BENCH-CAMPAIGN-README-TABLES.md THREE-ANGLE TRIANGULATION).
#
# Fixed WALL-TIME budget, iterations counted: a live doubling search (N=1,2,4,8,...) picks the largest N
# whose between+fail loop wrapper completes within TIME_BUDGET_MS, then reports iters/s = N / cpu_seconds.
# This N is DERIVED FRESH every run (never read from a committed file) -- the independence property the
# cross-proof needs against angle 2 (bench_prolog_fixed_iter.sh), which instead EXECUTES a pre-committed,
# historical N from corpus/benchmarks/prolog/fixed-iter-n.tsv. Same atomic operation (loop N times, measure),
# different SOURCE for N -- live-derived here, historically-committed there.
#
# ⛔ CORRECTNESS GATES THE TIMING (binding, ARCH-BENCH-CAMPAIGN-README-TABLES.md): this script re-verifies
# each kernel's SINGLE-SHOT output against corpus/benchmarks/prolog/bench/<k>.ref on gnu/swi/m3 before
# ever timing it -- a kernel that fails this is SKIPped, never silently timed anyway.
#
# ⛔⭐ THE exit= FIELD IS THE ONLY TRUSTED CRASH SIGNAL (row bench-rivals-prolog, found live 2026-08-27):
# a segfaulting child still writes a well-formed BENCH_RUSAGE line -- grepping stderr TEXT for
# "segmentation"/"core dumped" missed real crashes (the shell's own job-control notice does not reliably
# land in a redirected stderr capture), and a crashed run's tiny cpu_us then read as an implausibly FAST
# measurement. See FINDING-2026-08-27-seat14-prolog-second-call-into-any-user-predicate-crashes-m3-m4.md.
# Every run here is gated on BENCH_RUSAGE's own exit= field, nothing else.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/prolog/bench}"
PRO="${PROLOG_DIR:-$S4E/corpus/benchmarks/prolog}"
# ⛔ NMAX WAS 65536 UNTIL CEO-1281 (2026-09-26) AND THAT CAP WAS THE GPROLOG DISAGREEMENT: gprolog's wall_us is real_time/1 x 1000, a
#   1 ms tick, and a kernel like cal (0.38 us/it on gprolog) reached the cap at 25 ms of work -- 25 ticks -- so its self-measured WORK
#   per iteration read 0.38 on one angle and 0.44 on the other (1.16x, DISAGREE) while its CPU rates agreed. The search now runs on to
#   the 500 ms budget for every engine (4194304 caps only a runaway), and angle 2's committed counts for the sub-3-us kernels were
#   raised the same day so its gprolog bracket holds 200 ms or more. T rose with it: a 4M-iteration run of a fast kernel is seconds.
T="${TIMEOUT:-60}"; BUDGET_MS="${TIME_BUDGET_MS:-500}"; NMAX="${NMAX:-4194304}"
KERNELS="${KERNELS:-}"   # optional allowlist, same convention as bench_prolog_fixed_iter.sh
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSED-TO-GRADE libscrip_rt.so not built"; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSED-TO-GRADE bench corpus missing: $B"; exit 2; }
gprolog_bin >/dev/null || exit 2
command -v swipl   >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE swipl absent"; exit 2; }
gplc_bin >/dev/null || exit 2
# ⛔ THE RIVAL PRELUDES ARE PART OF THE RIVAL INVOCATION, NOT AN OPTION (hq_P 2026-09-02, row prolog-instruments-and-baseline-standup).
# Ten of the 21 van Roy kernels are self-timed on the two-number basis and call wall_us/1 + wall_ms/1 -- SCRIP builtins that are
# UNDEFINED on gprolog/swipl unless prelude_gplc.pl / prelude_swipl.pl is consulted first. MEASURED before this line existed: every
# bracketed kernel failed the rival single-shot correctness gate with existence_error(wall_us/1), so its whole row read SKIP and the
# triangulation TSV published UNPROVEN for gnu AND swi -- an instrument defect printed in the vocabulary of a kernel finding (the
# 2026-09-02 "12 cells UNPROVEN in 6 s" null). bench_prolog_vanroy.sh --two-number already consults the preludes; this arm now runs
# the IDENTICAL rival invocation so the three angles and the two-number board grade one program. Missing prelude => REFUSE, never a
# plausible SKIP: a rival that cannot load its clock is not a rival that disagreed.
[ -f "$PRO/prelude_gplc.pl" ] && [ -f "$PRO/prelude_swipl.pl" ] || { echo "⛔ REFUSED-TO-GRADE rival preludes missing under $PRO (prelude_gplc.pl / prelude_swipl.pl)"; exit 2; }
. "$HERE/lib_prolog_bench.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE (rc=2): cannot source lib_prolog_bench.sh -- the ONE loop-output check"; exit 2; }
WRAP="$ROOT/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "⛔ REFUSED: bench_rusage failed to build" >&2; exit 2; }
# ⛔⭐ THE GENERATOR IS THE SOLE PRODUCER OF THE WRAPPED FORM (CEO-567 DONE-WHEN, verbatim: "the harness
#   is the sole producer of the wrapped self-timing self-counting form").  Until 2026-09-13 THIS SCRIPT
#   WAS A SECOND PRODUCER: a local mkwrap() that sed'd `main :-` into `bench__main :-` and wrapped it in
#   a frozen `l__(N)`.  It worked, which is why it survived -- but it emitted NO TIMING BRACKET, so angle
#   1 had a RATE and no WORK number, and the two-number basis could not exist on this angle at all.
#   ⭐ Routing through the generator is what fills the WORK and OVERHEAD grids below; the independence
#   property angle 1 exists for is UNTOUCHED, because what makes angle 1 independent is that N is
#   DERIVED FRESH by the doubling search, never where the wrapper text comes from.
GEN="${GEN:-$HERE/bench_prolog_wrap.sh}"
[ -x "$GEN" ] || { echo "⛔ REFUSED-TO-GRADE: the wrapper generator $GEN is missing or not executable -- angle 1 will not hand-roll a second wrapper (CEO-567)"; exit 2; }
. "$HERE/lib_perf_fmt.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot load lib_perf_fmt.sh -- the ONE authority for printing a multiple and the carrier of the load stamp (s266/CEO-697)"; exit 2; }
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: cannot load lib_declared_arena.sh -- the ONE reader of a program's declared stack and heap sidecars (CEO-1281)"; exit 2; }
# ⛔ THE SCRIP ARMS RUN UNDER THE KERNEL'S OWN DECLARATION (ceo CEO-1281, 2026-09-26): DECL_SW carries the <k>.heap / <k>.stack sidecars as
#   SPITBOL's -d<kb>k -s<kb>k switches (lib_declared_arena.sh, the suite runner's reader; a switch is recorded with the run, CEO-1225, and
#   SCRIP_HEAP_KB would move the WINDOW), and every m3 and m4 launch below -- the single-shot correctness gate included -- carries them. Before this line tak overflowed the
#   shipped 4 MB stack in the correctness gate and read SKIP on all four engines (an instrument gap wearing a kernel finding's words).
declare -a DECL_SW=(); declare -A DECLW=()
# ⛔ timeout -k 5 EVERYWHERE (hq_P 2026-09-02, measured): swipl ignores timeout's SIGTERM -- angle 2 sat 648 s on vanroy/queens.pl
# under `timeout 60` with the whole triangulation behind it. A bound that the bounded process can decline is not a bound; -k makes
# the kill unconditional five seconds after the deadline, and the run then reads CRASH(signal 9), never a rate (the exit= gate).
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# No ulimit here: SCRIP's stack is DECL_SW's -s, and the rivals' own stacks are theirs. Until 2026-10-01 this line was ulimit -s unlimited.
#   MEASURED 2026-10-01 at c1c899df3: all 23 kernels read the same on gprolog, swipl, m3 and m4 at the shell's soft 8 MB stack and at
#   unlimited, and the generated loop is failure-driven (between/3 then fail), so N never deepens a stack (RULES.md clause 8 (g), CEO-1353).

# genwrap SRC N OUT ENG -- ask the ONE generator for the counted, self-timing form.  ⛔ Never write the
# wrapper here: a second producer is how angle 1 came to have a rate and no work number for months.
genwrap() {
  local src="$1" n="$2" out="$3" eng="$4" ge
  case "$eng" in gnu|gplc) ge=gnu ;; swi) ge=swi ;; *) ge=scrip ;; esac
  "$GEN" "$src" --mode=iter --n="$n" --engine="$ge" -o "$out" >/dev/null 2>"$W/gen.err"
}

# one bench_rusage-wrapped run at N iterations; echoes "cpu_us" or "- REASON" -- exit= is the ONLY signal trusted
run1() {
  local eng="$1" pl="$2" n="${3:-}" exp="${4:-}" out rl xc user sys r
  case "$eng" in
    # ⛔⭐ NO SEPARATE --consult-file FOR THE PRELUDE HERE, AND THAT IS NOT AN OMISSION -- THE GENERATOR
    #   ALREADY INLINED IT (that is what --engine MEANS: it changes only the prelude, never the kernel).
    #   Passing it a second time defines wall_us/1 and wall_ms/1 TWICE, and gprolog then writes
    #   "cannot be redefined / previous definition" ON STDOUT, which gnu_filter does not catch -- so the
    #   run reads LOOP-OUTPUT-MISMATCH(lines=3/1) with the CORRECT answer sitting on the third line.
    #   MEASURED as a regression against the pre-generator control on nrev: gnu 33243/s ok -> NA.
    #   ⭐ A doubled prelude is invisible on every engine that tolerates redefinition and fatal on the
    #   one that does not, which is why this comment is longer than the fix.
    gnu) out=$("$WRAP" timeout -k 5 "$T" "$(gprolog_bin)" --consult-file "$pl" --query-goal halt >"$W/o.$$" 2>"$W/e.$$") ;;
    # ⭐ gplc -- GNU Prolog's NATIVE compiler (Prolog -> WAM -> mini-assembly -> x86-64, linked; ceo CEO-1281 on Lon's question of 2026-09-26,
    #   "Is GNU Prolog a true compiler?"): the gnu arm above is gprolog's BYTE-CODE WAM interpreter (a consulted file never becomes native
    #   code), so until this arm the grid compared SCRIP with two interpreters. Same generated program as gnu (--engine=gnu inlines the
    #   real_time/1 prelude), compiled here with --no-top-level so the binary exits after its initialization goals and prints no banner.
    #   MEASURED at the arm's birth: nrev at 65536 iterations, gplc 371 ms of work against 911-930 ms consulted -- about 2.5x.
    gplc) local gb="$W/$$.gplc"; rm -f "$gb"
         if ! (cd "$W" && timeout -k 5 "$T" "$(gplc_bin)" --no-top-level -o "$gb" "$pl" >/dev/null 2>&1) || [ ! -x "$gb" ]; then echo "- GPLC-BUILD-ERR"; return; fi
         out=$("$WRAP" timeout -k 5 "$T" "$gb" >"$W/o.$$" 2>"$W/e.$$") ;;
    swi) out=$("$WRAP" timeout -k 5 "$T" swipl -q -g halt "$pl" >"$W/o.$$" 2>"$W/e.$$") ;;
    m3)  out=$("$WRAP" timeout -k 5 "$T" "$SCRIP" --run "${DECL_SW[@]}" "$pl" >"$W/o.$$" 2>"$W/e.$$") ;;
    m4)  local s="$W/$$.s" b="$W/$$.bin"
         if ! (cd "$W" && timeout -k 5 "$T" "$SCRIP" --compile --target=x86 "$pl" </dev/null >"$s" 2>/dev/null) || [ ! -s "$s" ]; then echo "- BUILD-ERR"; return; fi
         if ! (as --64 -o "$W/$$.o" "$s" 2>/dev/null && gcc -no-pie -o "$b" "$W/$$.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null); then echo "- LINKFAIL"; return; fi
         out=$("$WRAP" timeout -k 5 "$T" "$b" "${DECL_SW[@]}" >"$W/o.$$" 2>"$W/e.$$") ;;
  esac
  rl=$(grep '^BENCH_RUSAGE:' "$W/e.$$" 2>/dev/null | tail -1)
  [ -n "$rl" ] || { echo "- DNF"; return; }
  xc=$(echo "$rl" | grep -oE 'exit=[0-9-]+' | cut -d= -f2)
  case "$xc" in ''|*[!0-9]*) echo "- CRASH(exit=${xc:-?})"; return ;; esac
  [ "$xc" -ge 128 ] && { echo "- CRASH(signal $((xc-128)))"; return; }
  [ "$xc" -ne 0 ] && { echo "- NONZERO($xc)"; return; }
  r=$(loop_check "$eng" "$W/o.$$" "$n" "$exp") || { echo "- $r"; return; }
  user=$(echo "$rl" | grep -oE 'user_us=[0-9]+' | cut -d= -f2); sys=$(echo "$rl" | grep -oE 'sys_us=[0-9]+' | cut -d= -f2)
  # ⛔⛔ THE SUBTRACTION IS WALL MINUS WALL AND THAT IS THE APPLES-TO-APPLES LAW, NOT A DETAIL.
  #   bench_rusage reports BOTH elapsed_ns (CLOCK_MONOTONIC) and user_us+sys_us (CPU).  The RATE column
  #   of this angle deliberately uses the CPU pair -- but wall_us/1 inside the generated bracket is
  #   CLOCK_MONOTONIC, so `user+sys - work` would subtract a WALL number from a CPU one and publish the
  #   difference of two instruments as an overhead.  On a loaded box it can go NEGATIVE, which is the
  #   tell.  elapsed_us is therefore carried separately, for this one purpose only.
  local elns work
  elns=$(echo "$rl" | grep -oE 'elapsed_ns=[0-9]+' | cut -d= -f2)
  work=$(grep -oE 'work_us=[0-9]+' "$W/e.$$" 2>/dev/null | tail -1 | cut -d= -f2)
  echo "$(( ${user:-0} + ${sys:-0} )) $(( ${elns:-0} / 1000 )) ${work:--}"
}
# doubling search: largest N whose cpu time >= BUDGET_MS, cap NMAX. Echoes "N rate" or "N -" + reason on the FIRST N that fails.
search() {
  local eng="$1" src="$2" N=1 res cpu el wk
  while :; do
    if ! genwrap "$src" "$N" "$W/s.pl" "$eng"; then
      echo "$N - GEN-REFUSED($(head -1 "$W/gen.err" 2>/dev/null | cut -c1-40))"; return
    fi
    res=$(run1 "$eng" "$W/s.pl" "$N" "${src%.pl}.ref")
    cpu=$(awk '{print $1}' <<<"$res")
    case "$cpu" in
      -) echo "$N - $(cut -d' ' -f2- <<<"$res")"; return ;;   # first failure at this N -- report it, caller decides
    esac
    if [ "$cpu" -ge $((BUDGET_MS*1000)) ] || [ "$N" -ge "$NMAX" ]; then
      el=$(awk '{print $2}' <<<"$res"); wk=$(awk '{print $3}' <<<"$res")
      awk -v n="$N" -v us="$cpu" -v e="$el" -v w="$wk" 'BEGIN{printf "%d %.4f %s %s", n, n/(us/1e6), e, w}'; return
    fi
    N=$((N*4)); [ "$N" -gt "$NMAX" ] && N=$NMAX
  done
}

echo "TIME-BASED PROLOG BENCHMARKS -- angle 1: fixed wall-time budget (${BUDGET_MS}ms), iterations counted via live doubling search"
echo "engines: gnu gplc swi m3 m4 (gnu = "$(gprolog_bin)" --consult-file, the byte-code WAM; gplc = GNU Prolog compiled native)   corpus: $B   budget: TIME_BUDGET_MS=$BUDGET_MS cap NMAX=$NMAX   external instrument: tools/bench_rusage"
echo "wrapper: GENERATED per engine by $(basename "$GEN") --mode=iter (never checked in, CEO-567 -- this angle no longer writes its own)"
# ⛔ CEO-697: A COST WITHOUT THE LOAD IT RAN UNDER IS NOT A COST, and perf_grid_begin welds the load to
#   the shared-axes line so this harness CANNOT print a rate without it -- two runs of one tree on this
#   box have been measured differing by up to 2.15x.
perf_grid_begin "Prolog kernels vs gnu/swi -- angle 1, live doubling search · rate = iterations / CPU(user+sys) · WORK = self-measured wall inside the bracket · RT_OPT=-O0"
echo
printf "%-14s %14s %14s %14s %14s %14s  %s\n" BENCHMARK gnu/s gplc/s swi/s m3/s m4/s check
printf "%-14s %14s %14s %14s %14s %14s  %s\n" "--------------" "--------------" "--------------" "--------------" "--------------" "--------------" "-----"
tot_ok=0; tot_skip=0; tot_dark_rows=0
declare -A BWORK=(); declare -A BOVH=(); declare -A BN=(); basis_rows=()
for pl in "$B"/*.pl; do
  [ -e "$pl" ] || continue
  k=$(basename "${pl%.pl}"); exp="${pl%.pl}.ref"
  [ -f "$exp" ] || continue
  if [ -n "$KERNELS" ]; then case " $KERNELS " in *" $k "*) ;; *) continue ;; esac; fi
  want=$(cat "$exp")
  DECL_SW=(); dw=$(declared_switches_beside "$pl") || { echo "⛔ REFUSED-TO-GRADE: $k: a .stack or .heap sidecar the reader refuses (it said why above) -- a program whose declaration cannot be read is not timed under the default it did not ask for"; exit 2; }
  [ -n "$dw" ] && { read -r -a DECL_SW <<<"$dw"; DECLW["$k"]="$dw"; }
  go=$(cd "$W" && timeout -k 5 15 "$(gprolog_bin)" --consult-file "$PRO/prelude_gplc.pl" --consult-file "$pl" --query-goal halt 2>/dev/null </dev/null | gnu_filter)
  so=$(cd "$W" && timeout -k 5 15 swipl -q -g halt "$PRO/prelude_swipl.pl" "$pl" 2>/dev/null </dev/null | head -200)
  m3o=$(cd "$W" && timeout -k 5 15 "$SCRIP" --run "${DECL_SW[@]}" "$pl" </dev/null 2>/dev/null | head -200)
  # ⛔ A gplc REFUSAL DARKENS THE gplc CELL, NEVER THE KERNEL (CEO-1281, found the hour the arm was born): witness_depth_nrev8 defines
  #   append/3, which gplc refuses as "redefining built-in predicate append/3" where gprolog's consult only prints an error line and runs
  #   the built-in -- the kernel is OUTSIDE THE gplc BASELINE (RULES.md § THE OUTSIDE-BASELINE TEST IS ABOUT THE ORACLE), and the first
  #   cut of this gate SKIPped the whole kernel on all five engines for it. The three engines that decide SKIP stay gnu, swi and m3.
  gpo=$(cd "$W" && rm -f ss.gplc && "$(gplc_bin)" --no-top-level -o ss.gplc "$pl" >/dev/null 2>&1 && timeout -k 5 15 ./ss.gplc </dev/null 2>/dev/null | head -200)
  gp_ok=1; [ "$gpo" = "$want" ] || gp_ok=0
  if [ "$go" != "$want" ] || [ "$so" != "$want" ] || [ "$m3o" != "$want" ]; then
    printf "%-14s %14s %14s %14s %14s %14s  %s\n" "$k" SKIP SKIP SKIP SKIP SKIP "correctness-fail(single-shot$([ "$go" != "$want" ] && printf " gnu")$([ "$gpo" != "$want" ] && printf " gplc")$([ "$so" != "$want" ] && printf " swi")$([ "$m3o" != "$want" ] && printf " m3"))"; tot_skip=$((tot_skip+1)); continue
  fi
  declare -A R=() C=()
  for eng in gnu gplc swi m3 m4; do
    if [ "$eng" = gplc ] && [ "$gp_ok" = 0 ]; then
      R[gplc]="NA"; C[gplc]="gplc:single-shot-refused-or-wrong(outside the gplc baseline)"; BWORK["$k:gplc"]="NA"; BOVH["$k:gplc"]="NA"; BN["$k:gplc"]="-"
      perf_dark_cell "$k/gplc" "gplc refused or misanswered the kernel single-shot (a built-in redefined, or an answer the .ref does not carry)"; continue
    fi
    res=$(search "$eng" "$pl"); n=$(awk '{print $1}' <<<"$res")
    r=$(awk '{print $2}' <<<"$res")
    case "$r" in
      -) R[$eng]="NA"; C[$eng]="$eng@N=$n:$(cut -d' ' -f3- <<<"$res")"
         # ⛔⭐ THE BUMP IS WHAT MAKES perf_grid_end ABLE TO REFUSE, AND WITHOUT IT THIS ANGLE'S GRID
         #   VERDICT WAS STRUCTURALLY UNABLE TO FIRE (hq_P 2026-09-13, my own defect from the sitting
         #   before).  The literal "NA" printed here never touched PERF_DARK_CELLS, so the counter
         #   perf_grid_end reads was never bumped by the cells it exists to count -- and the close was
         #   `perf_grid_end || true`, which discarded even that.  A reader seeing perf_grid_end in this
         #   file believed the grid could refuse.  It could not.  ONE BUMP PER UNMEASURED (kernel,
         #   engine) PAIR, not per printed cell: one failed search darkens the same measurement in all
         #   three grids below, and counting it three times would say three things went wrong.
         perf_dark_cell "$k/$eng" "search returned no rate: $(cut -d' ' -f3- <<<"$res")"
         BWORK["$k:$eng"]="NA"; BOVH["$k:$eng"]="NA"; BN["$k:$eng"]="-" ;;
      *) R[$eng]="$r"
         el=$(awk '{print $3}' <<<"$res"); wk=$(awk '{print $4}' <<<"$res"); BN["$k:$eng"]="$n"
         # ⛔ A MISSING work_us IS PRINTED AS DARK, NEVER BLANK AND NEVER ZERO (CEO-676, dark-is-worse-
         #   than-red): an engine whose bracket did not report could not measure its subject, and it
         #   must say so in its own voice rather than leave the column looking filled.
         # ⛔⭐ WORK IS PUBLISHED PER ITERATION, AND ON THIS ANGLE THAT IS MANDATORY, NOT A PREFERENCE.
         #   Angle 2 can print raw work_us because ONE committed N is used for every engine, so its row
         #   is already apples-to-apples.  Angle 1's N is DERIVED PER ENGINE by the doubling search, so
         #   a raw work_us row compares gnu at its N against m4 at a different one -- a grid that looks
         #   like a comparison and is not.  MEASURED on nrev: m3 work 122476 us at its N beside m4
         #   1024762 us at ITS N, an 8x that is entirely the two N's and says nothing about either
         #   engine.  Dividing by N is what makes the column mean one thing.
         case "$wk" in ''|-|*[!0-9]*) BWORK["$k:$eng"]="DARK"; BOVH["$k:$eng"]="DARK"
              perf_dark_cell "$k/$eng" "the generated bracket reported no work_us" ;;
           *) BWORK["$k:$eng"]=$(awk -v w="$wk" -v n="$n" 'BEGIN{printf "%.4f", (n>0)?w/n:0}')
              BOVH["$k:$eng"]=$(( el - wk )) ;; esac ;;
    esac
  done
  basis_rows+=("$k")
  # ⛔⭐ EVERY FAILING ENGINE IS NAMED, NOT WHICHEVER ONE THE LOOP VISITS LAST (hq_P 2026-09-13, measured).
  #   This line used to ASSIGN in a loop, so the last non-empty reason overwrote the rest and a row where
  #   all four engines failed reported ONE cause -- always m4's, since m4 is last.  MEASURED on the four
  #   kernels that were NA on every engine: the board read "m4@N=1:NONZERO(124)" and a reader concluded m4
  #   was the problem, when gnu, swi and m3 had failed too.  An instrument that reports one cause for four
  #   failures is not shorter, it is wrong about WHICH SUBJECT is broken.
  ckstat=ok; for eng in gnu gplc swi m3 m4; do [ -n "${C[$eng]:-}" ] && { [ "$ckstat" = ok ] && ckstat="${C[$eng]}" || ckstat="$ckstat; ${C[$eng]}"; }; done
  [ "$ckstat" = ok ] && tot_ok=$((tot_ok+1)) || tot_dark_rows=$((tot_dark_rows+1))
  printf "%-14s %14s %14s %14s %14s %14s  %s\n" "$k" "${R[gnu]:-NA}" "${R[gplc]:-NA}" "${R[swi]:-NA}" "${R[m3]:-NA}" "${R[m4]:-NA}" "$ckstat"
done
# ⭐⭐ THE TWO-NUMBER WORK/OVERHEAD BASIS ON ANGLE 1 -- the CEO-567 DONE-WHEN clause "the three angles
#   run over the wrapped form with the process wrapper's numbers printed beside the self-measured ones".
#   ⛔ THIS ANGLE COULD NOT CARRY THESE TWO GRIDS AT ALL BEFORE 2026-09-13, and for two stacked reasons,
#   each of which alone was enough: (a) the local mkwrap() emitted no timing bracket, so there was no
#   self-measured number to print; (b) SCRIP's Prolog had no wall clock at any spelling, so even a
#   bracket would have been dark on m3 and m4.  (b) was cured by the cto landing wall_us/1 (05317a5fb)
#   and (a) by routing this angle through the generator above.
echo
echo "N ACTUALLY RUN, PER ENGINE -- the basis of both grids below, printed because it DIFFERS per engine"
echo "  ⛔ angle 1 derives N live per engine (that is the independence property it exists for), so a RAW"
echo "  work_us column here would compare each engine at a different N. Read the two grids with these N."
printf "%-14s %14s %14s %14s %14s %14s\n" BENCHMARK gnu gplc swi m3 m4
printf "%-14s %14s %14s %14s %14s %14s\n" "--------------" "--------------" "--------------" "--------------" "--------------" "--------------"
for k in "${basis_rows[@]}"; do
  printf "%-14s %14s %14s %14s %14s %14s\n" "$k" "${BN[$k:gnu]:--}" "${BN[$k:gplc]:--}" "${BN[$k:swi]:--}" "${BN[$k:m3]:--}" "${BN[$k:m4]:--}"
done
echo
echo "SELF-MEASURED WORK PER ITERATION (us/iter) = work_us / N -- read from INSIDE the generated bracket,"
echo "  wall clock (CLOCK_MONOTONIC). THIS is the column comparable across engines: it excludes process"
echo "  startup entirely AND divides out each engine's own N."
echo "  ⛔ PRECISION FLOOR: gprolog's wall_us is real_time/1 x 1000 -- a UNIT CONVERSION of a 1 ms tick,"
echo "  not sub-ms precision (prelude_gplc.pl says so in its own header). A gnu cell whose work_us is a"
echo "  few thousand is a few TICKS; do not build a multiple on it."
printf "%-14s %14s %14s %14s %14s %14s\n" BENCHMARK gnu gplc swi m3 m4
printf "%-14s %14s %14s %14s %14s %14s\n" "--------------" "--------------" "--------------" "--------------" "--------------" "--------------"
for k in "${basis_rows[@]}"; do
  printf "%-14s %14s %14s %14s %14s %14s\n" "$k" "${BWORK[$k:gnu]:-DARK}" "${BWORK[$k:gplc]:-DARK}" "${BWORK[$k:swi]:-DARK}" "${BWORK[$k:m3]:-DARK}" "${BWORK[$k:m4]:-DARK}"
done
echo
echo "OVERHEAD (us, PER RUN not per iteration) = external elapsed (tools/bench_rusage, CLOCK_MONOTONIC)"
echo "  MINUS self-measured work. It is startup+load+teardown, which the kernel never did; it is roughly"
echo "  N-independent, which is why it is NOT divided by N the way the work column above is."
echo "  ⛔ wall minus wall, never CPU minus wall -- the rate column above uses CPU and is a DIFFERENT"
echo "  instrument; subtracting across the two would publish the difference of two clocks as an overhead."
echo "  DARK = the engine ran but its bracket reported no work_us; it is named, never left blank (CEO-676)."
printf "%-14s %14s %14s %14s %14s %14s\n" BENCHMARK gnu gplc swi m3 m4
printf "%-14s %14s %14s %14s %14s %14s\n" "--------------" "--------------" "--------------" "--------------" "--------------" "--------------"
for k in "${basis_rows[@]}"; do
  printf "%-14s %14s %14s %14s %14s %14s\n" "$k" "${BOVH[$k:gnu]:-DARK}" "${BOVH[$k:gplc]:-DARK}" "${BOVH[$k:swi]:-DARK}" "${BOVH[$k:m3]:-DARK}" "${BOVH[$k:m4]:-DARK}"
done
echo
echo "DECLARED SIDECARS carried as switches on the m3 and m4 command lines (lib_declared_arena.sh, the suite runner's reader; CEO-1281): ${#DECLW[@]} kernel(s)"
for k in "${!DECLW[@]}"; do echo "  $k: ${DECLW[$k]}"; done
echo
# ⛔⭐ THE VERDICT FOLDS IN, AND THAT IS A RULING THE MEASUREMENT EARNED RATHER THAN A PREFERENCE.
#   The open question was whether this angle carries STANDING unmeasurable cells: if it did, bumping
#   would make it ALWAYS RED, and a verdict that is always red is one nobody reads -- which is how a
#   REAL dark cell would then travel unnoticed beside it (lib_perf_fmt.sh's DARK-CELL LAW, and the
#   reason the TICK-FLOOR class deliberately does NOT bump).  MEASURED FIRST, as the row required:
#   the board carried 48 NA cells over four kernels, every one of them a CURABLE defect in the
#   generated wrapper rather than a permanent property of an instrument.  Curing it (SCRIP 9968d7fdf)
#   took the board to ZERO NA cells, so folding costs nothing today and the counter now means what it
#   says.  ⛔ A future standing dark cell is therefore a DECISION to make here again, with a number.
perf_grid_end; grid_rc=$?
# ⛔ THE THREE NUMBERS MUST SUM TO THE POPULATION, AND UNTIL NOW THEY DID NOT (hq_P 2026-09-13).  A row
#   that was NA on every engine was neither ok nor a correctness-skip, so it fell out of BOTH counters:
#   the board printed "measured=18 correctness-skip=1" over 23 kernels and four kernels simply vanished.
#   ⭐ A SUMMARY WHOSE PARTS DO NOT ADD UP TO ITS WHOLE CANNOT REPORT AN ABSENCE -- it can only ever
#   report what it found, which is the one thing a reader does not need an instrument for.
echo "CHECK RESULT: measured=$tot_ok correctness-skip=$tot_skip unmeasured=$tot_dark_rows of $((tot_ok+tot_skip+tot_dark_rows)) kernels"
[ "$tot_skip" -eq 0 ] && [ "$grid_rc" -eq 0 ]
