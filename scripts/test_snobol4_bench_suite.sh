#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${BENCH_SNOBOL4_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/corpus/benchmarks/snobol4}" || exit 2
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# test_snobol4_bench_suite.sh [--no-write] -- THE SNOBOL4 BENCHMARKS GRADED AS TESTS: every kernel under corpus/benchmarks/snobol4, both
# modes, all three angles, its REF checked on every run (the SnoBench row of SCORE.md THE SUITE TABLE; Lon 2026-09-24 14:2x, in-chat
# to the ceo: create a runner for SnoBench; built by the ceo on the shape of test_rebus_bench_suite.sh, the coo's COO-164 contract).
# Lon 2026-09-23, verbatim: "The reason to force a benchmark to also be a test is to guarantee it is not vacuous." -- "The source of
# the benchmark is the apple-core of the test, the wrapper code can be added to do both the test and the measurements."
#
# POPULATION: every *.sno directly under the benchmark tree, by extension -- never a kernel list, so a kernel added later is graded
# the day it lands; demo/ is a separate population (the workload demos, bench_triangulate_demos_snobol4.sh). Each kernel's .ref is
# the standalone program's real output, cut from sbl -bf (RULES.md THE KERNEL CONVENTION, s265: the .sno IS the application).
# No kernel reads input, so no IN.
# THE CRITERION: a kernel passes a mode when every angle prints exactly its .ref with rc 0, and passes the row in BOTH modes
# (m3 --run; m4 --compile, assembled and linked against out/libscrip_rt.so the way corpus_suite_harness.py links, run as a process).
#   (1) PROCESS WRAPPER -- the PRISTINE kernel once under tools/bench_rusage, the external stopwatch (stdout untouched).
#   (2) FIXED ITERATIONS -- the program bench_wrap_snobol4.py GENERATES from the kernel (--mode iter): the test once (its stdout
#       must be the .ref), then one warm-up and BENCH_ITER_N quiet repetitions of the kernel function named by the kernel's
#       *BENCH line (or of its whole main section when it has none); its BENCH line must read iters=N and mismatched=0.
#   (3) FIXED TIME LIMIT -- the same generator (--mode time): quiet repetitions until BENCH_BUD_MS is spent; at least one,
#       mismatched=0. A wrapper run with no BENCH line is UNMEASURED, and that is a FAIL here, never a pass.
#   The `value=` on the BENCH line is the kernel function's own census (not the .ref, which the test half already held):
#   the runner holds it to the FIRST repetition through mismatched=0.
# MEMORY: a kernel that needs more than the shipped arena or stack declares it beside itself -- NAME.heap and NAME.stack, one line
# NAME TAB KB each -- read through lib_declared_arena.sh (CEO-1171's floors), exported for THAT program only (CEO-1225).
# ⛔ TIMING IS SCOUTING, NOT PUBLISHED: the BENCH and BENCH_RUSAGE numbers are printed per run; no rate enters a grid from here
# (bench_triangulate_snobol4.sh is the timing instrument). CEO-1222: REF only -- each run's stdout lives in a temp dir that is deleted.
# PUBLISH: the board is the SNOBOL4 lane's (MODE LANES snobol4=hq_snobol4). One progress row per kernel per mode (class benchmark,
# suite snobol4-bench-ref, config declared) is appended when the population is the corpus tree; a whole-population pass then calls util_score_row.py by default (CEO-1302 (a), --no-write opts out)
# write --lang snobol4 --column bench-ref, whose lane check admits only the lane's seat. A population OUTSIDE the corpus tree
# (a fixture, BENCH_SNOBOL4_DIR) is not a board (CEO-547): it is graded, and nothing is appended or written.
# THE ORACLE ARM (BENCH_ORACLE_ARM=1; Lon 2026-09-24 15:1x: run the same 23 on SPITBOL using the 3-angle harness and show the
# comparison): the same pristine kernel and the SAME generated twins run under the CLEAN SPITBOL benchmark oracle (sbl_clean_bin,
# lib_oracle_flags.sh -- official upstream plus its two class-A patches, TIME() in nanoseconds; never the monitor-hooked x64/bin/sbl,
# which costs ~2.3x), printed as `scouting <k> sbl:` lines beside the m3/m4 ones and an informational `<k> sbl PASS|FAIL` line
# (stdout == .ref on every angle, mismatched=0). The oracle arm never enters the board line: the row grades SCRIP.
# EXIT 0 every kernel PASS; 1 any kernel not PASS; 2 REFUSED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
BD="${BENCH_SNOBOL4_DIR:-$S4E/corpus/benchmarks/snobol4}"
GATE_NAME=test_snobol4_bench_suite
LANG_KEY=snobol4; SUITE_KEY=snobol4-bench-ref; EXT=sno
SCRIP="$HERE/../../SCRIP/scrip"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
ITER_N="${BENCH_ITER_N:-3}"
BUD_MS="${BENCH_BUD_MS:-200}"
NOWRITE=0; [ "${1:-}" = --no-write ] && NOWRITE=1   # ⭐ PUBLISHING IS THE DEFAULT (ceo CEO-1302 (a), lib_bench_write.sh): a whole-population pass writes its row, a subset or --no-write never does; --write is still accepted and changes nothing
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$BD" ] || refuse "no benchmark tree at $BD"
# ⭐ UNDER A PORT ENGINE THIS RUNNER GRADES THE PORT WITH ITS OWN GRADING (S4E_ENGINE=dotnet|jvm; CEO-1822; Lon 2026-10-18, in-chat to hq_dotnet,
# verbatim: "Get all SNOBOL4 package runners working with snobol4dotnet."): SCRIP is the port's face (one_runner_port_face), the port runner's
# --binaries is the one check, each kernel runs its three angles in m3 alone with its declared heap and stack as switches, angle 1's external
# stopwatch is /usr/bin/time (SCRIP's tools/bench_rusage lives in SCRIP, which a port root does not hold; stdout untouched either way), the rows
# are keyed snobol4-bench-ref@<engine> by the one writer, and no SCRIP score row is written. Under scrip every line reads as it did.
PORT=0; one_runner_is_port && PORT=1
MODES="m3 m4"; [ "$PORT" = 1 ] && MODES=m3
# ⭐ ANGLE 3 BUDGETS BY TIME(), IN THE ENGINE'S OWN UNIT: the generator spells the budget in nanoseconds (SCRIP's rt_time_ns; the fleet's
# SPITBOLs answer the same by NS-TIME), and a port declares its unit through one_runner_port_time_unit_ns -- snobol4dotnet mimics SPITBOL
# exactly (Lon 2026-10-18), whose TIME() is milliseconds, so it runs at 1000000 ns per unit (read as nanoseconds, its 200 ms budget was 55
# hours and every kernel rode the 300 s cap, measured 2026-10-18). A port with no declared unit is graded on angles 1 and 2, said on the line.
TUARG=(); TIME_ANGLE=1
if [ "$PORT" = 1 ]; then TU="$(one_runner_port_time_unit_ns)"; if [ -n "$TU" ]; then TUARG=(--time-unit-ns "$TU"); else TIME_ANGLE=0; fi; fi
ANGLES=process,iter,time; [ "$TIME_ANGLE" = 0 ] && ANGLES=process,iter
if [ "$PORT" = 1 ]; then SCRIP="$(one_runner_port_face)"; one_runner_port_ready snobol4 || refuse "the $(one_runner_engine) engine is not ready (its runner said why above)"; else
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT_DIR/libscrip_rt.so" || exit 2
fi
. "$HERE/lib_declared_arena.sh" 2>/dev/null || refuse "lib_declared_arena.sh unloadable -- the one reader of a declared arena"
. "$HERE/lib_progress.sh" 2>/dev/null || refuse "lib_progress.sh unloadable"
GEN="$HERE/bench_wrap_snobol4.py"; [ -f "$GEN" ] || refuse "no wrapper generator at $GEN -- angles 2 and 3 have nothing to run"
WRAP="$HERE/../../SCRIP/tools/bench_rusage"
if [ "$PORT" = 1 ]; then WRAPV=(/usr/bin/time -f 'BENCH_RUSAGE: elapsed_s=%e user_s=%U sys_s=%S maxrss_kb=%M exit=%x'); [ -x /usr/bin/time ] || refuse "no /usr/bin/time -- angle 1 has no external stopwatch under a port"
else
[ -x "$WRAP" ] || gcc -O0 -o "$WRAP" "$HERE/../../SCRIP/tools/bench_rusage.c" || refuse "tools/bench_rusage failed to build -- angle 1 has no wrapper"
WRAPV=("$WRAP")
fi
case "$ITER_N" in ''|*[!0-9]*|0) refuse "BENCH_ITER_N must be a positive integer (got '$ITER_N')";; esac
case "$BUD_MS" in ''|*[!0-9]*|0) refuse "BENCH_BUD_MS must be a positive whole number of milliseconds (got '$BUD_MS')";; esac
ORACLE_ARM="${BENCH_ORACLE_ARM:-0}"; SBL=""
if [ "$ORACLE_ARM" = 1 ]; then
  . "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unloadable -- the one oracle-flag authority"
  SBL="$(sbl_clean_bin 2>/dev/null)"; [ -n "$SBL" ] && [ -x "$SBL" ] || refuse "BENCH_ORACLE_ARM=1 but sbl_clean_bin names no executable ($SBL)"
fi
IS_BOARD=0; one_runner_suite_is_a_board "$BD" && IS_BOARD=1
mapfile -t KERNELS < <(find "$BD" -maxdepth 1 -type f -name "*.$EXT" -printf '%f\n' | sed "s/\.$EXT\$//" | LC_ALL=C sort)
[ "${#KERNELS[@]}" -gt 0 ] || refuse "no *.$EXT under $BD -- a population of zero is not a green board"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PROG_ROWS="$T/progress.tsv"; : >"$PROG_ROWS"
run1() {
  local o="$1" kb="$2"; shift 2
  ( cd "$T" && [ -n "$kb" ] && export SCRIP_HEAP_CAP_KB="$kb" && unset SCRIP_HEAP_MB SCRIP_HEAP_KB; [ -n "${st:-}" ] && export SCRIP_STACK="${st}k"
    "$TIMEOUT_RETRY" 300s "$@" </dev/null >"$o.out" 2>"$o.err" )
}
build4() {
  ( cd "$T" && "$TIMEOUT_RETRY" 300s "$SCRIP" --compile "$1" -o "$2.s" </dev/null >"$2.cc" 2>&1 ) \
    && ( cd "$T" && gcc -c "$2.s" -o "$2.o" >>"$2.cc" 2>&1 && gcc "$2.o" -o "$2" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >>"$2.cc" 2>&1 )
}
# bench_ok <err-file> <mode> -- the generated wrapper's BENCH line holds: its mode, its iteration count, no mismatch
bench_ok() {
  local b; b="$(grep -m1 '^BENCH mode=' "$1")" || { echo "no BENCH line (UNMEASURED)"; return 1; }
  case "$b" in *"mode=$2 "*) ;; *) echo "BENCH line of the wrong mode: $b"; return 1;; esac
  local it mm; it="$(sed -n 's/.* iters=\([0-9]*\) .*/\1/p' <<<"$b")"; mm="$(sed -n 's/.* mismatched=\([0-9]*\) .*/\1/p' <<<"$b")"
  [ "$2" = iter ] && [ "$it" != "$ITER_N" ] && { echo "iters=$it, not the $ITER_N asked for"; return 1; }
  [ "${it:-0}" -ge 1 ] || { echo "iters=${it:-?}: no repetition ran"; return 1; }
  [ "$mm" = 0 ] || { echo "mismatched=${mm:-?}: a repetition computed another value"; return 1; }
  return 0
}
printf '%-20s %-4s %-7s %-7s %-7s %s\n' kernel mode process iter time verdict
declare -A PASSN; PASSN[m3]=0; PASSN[m4]=0; BOTH=0; TOTAL=0; NAMED=""; HEAPD=0
for k in "${KERNELS[@]}"; do
  TOTAL=$((TOTAL+1)); f="$BD/$k.$EXT"; ref="$BD/$k.ref"
  kb="$(declared_arena_kb_beside "$f")" || refuse "$k: its .heap sidecar is refused (the reader said why above)"
  st="$(declared_stack_kb_beside "$f")" || refuse "$k: its .stack sidecar is refused (the reader said why above)"
  cfg="shipped"; [ -n "$kb" ] && { cfg="SCRIP_HEAP_CAP_KB=$kb"; HEAPD=$((HEAPD+1)); }
  [ -n "$st" ] && { cfg="$([ "$cfg" = shipped ] || printf '%s,' "$cfg")SCRIP_STACK=${st}k"; HEAPD=$((HEAPD+1)); }
  if [ ! -s "$ref" ]; then
    for m in $MODES; do printf 'benchmark\t%s\t%s\t%s\t%s\tFAIL\t0\tno-ref\t%s\n' "$SUITE_KEY" "$LANG_KEY" "$k" "$m" "$cfg" >>"$PROG_ROWS"; done
    printf '%-20s %-4s %s\n' "$k" both "FAIL no .ref -- a benchmark without a REF cannot be graded, and is counted, not skipped"; NAMED="$NAMED $k(no-ref)"; continue
  fi
  gen_ok=1
  for a in iter time; do python3 "$GEN" "$f" --mode "$a" --n "$ITER_N" --bud-ms "$BUD_MS" ${TUARG[@]+"${TUARG[@]}"} -o "$T/$k.$a.$EXT" 2>"$T/$k.$a.gen" || gen_ok=0; done
  okboth=1
  sz=""; [ "$PORT" = 1 ] && { sz="$(declared_switches_beside "$f")" || refuse "$k: a .heap or .stack sidecar is refused (the reader said why above)"; }   # a port reads its declared heap and stack as -dNk -sNk
  for m in $MODES; do
    _tm="$(progress_clock)"   # the mode's own wall for its row: its three angles, and in m4 their compile and link (CEO-1676 (c))
    r1=FAIL; r2=FAIL; r3=FAIL; why=""
    if [ "$gen_ok" = 0 ]; then why="the wrapper generator REFUSED: $(head -c 160 "$T/$k.iter.gen" "$T/$k.time.gen" 2>/dev/null | tr '\n' ' ')"
    else
      if [ "$m" = m3 ]; then P=("$SCRIP" --run $sz "$f"); I=("$SCRIP" --run $sz "$T/$k.iter.$EXT"); TM=("$SCRIP" --run $sz "$T/$k.time.$EXT")
      else
        if build4 "$f" "$T/$k.p4" && build4 "$T/$k.iter.$EXT" "$T/$k.i4" && build4 "$T/$k.time.$EXT" "$T/$k.t4"; then P=("$T/$k.p4"); I=("$T/$k.i4"); TM=("$T/$k.t4")
        else why="m4 compile/link failed: $(cat "$T/$k.p4.cc" "$T/$k.i4.cc" "$T/$k.t4.cc" 2>/dev/null | head -c 160 | tr '\n' ' ')"; fi
      fi
      if [ -z "$why" ]; then
        run1 "$T/$k.$m.p" "$kb" "${WRAPV[@]}" "${P[@]}"; rc=$?
        if [ "$rc" = 0 ] && cmp -s "$T/$k.$m.p.out" "$ref"; then r1=PASS; else why="process: rc=$rc$(cmp -s "$T/$k.$m.p.out" "$ref" || echo ', output differs from .ref')"; fi
        run1 "$T/$k.$m.i" "$kb" "${I[@]}"; rc=$?; w="$(bench_ok "$T/$k.$m.i.err" iter)"
        if [ "$rc" = 0 ] && cmp -s "$T/$k.$m.i.out" "$ref" && [ -z "$w" ]; then r2=PASS; else why="$why; iter: rc=$rc$(cmp -s "$T/$k.$m.i.out" "$ref" || echo ', stdout differs from .ref')${w:+, $w}"; fi
        if [ "$TIME_ANGLE" = 0 ]; then r3=PASS; rc=0; w=""   # a port with no declared TIME() unit does not run angle 3 (ANGLES above); the table prints -
        else run1 "$T/$k.$m.t" "$kb" "${TM[@]}"; rc=$?; w="$(bench_ok "$T/$k.$m.t.err" time)"; fi
        if [ "$TIME_ANGLE" = 0 ]; then :
        elif [ "$rc" = 0 ] && cmp -s "$T/$k.$m.t.out" "$ref" && [ -z "$w" ]; then r3=PASS; else why="$why; time: rc=$rc$(cmp -s "$T/$k.$m.t.out" "$ref" || echo ', stdout differs from .ref')${w:+, $w}"; fi
        grep -h '^BENCH_RUSAGE' "$T/$k.$m.p.err" | sed "s/^/    scouting $k $m: /"
        for x in i t; do grep -hs '^BENCH mode=' "$T/$k.$m.$x.err" | sed "s/^/    scouting $k $m: /"; done
      fi
    fi
    if [ "$r1$r2$r3" = PASSPASSPASS ]; then v=PASS; PASSN[$m]=$((PASSN[$m]+1)); note="ref-under-three-angles"
    # a wrapper the generator refused is no grade of the program: REFUSE, could not measure, never FAIL (the coo 2026-10-22, COO-396: RakBench's four
    # 10-15 refusals read FAIL in the red lists the cto was sent)
    else v=FAIL; [ "$gen_ok" = 0 ] && v=REFUSE; okboth=0; note="$(echo "$why" | sed 's/^[; ]*//' | tr '\t' ' ')"; NAMED="$NAMED $k.$m$([ "$v" = REFUSE ] && echo "(refused)")"; fi
    SM="$(progress_secs_since "$_tm")"
    printf 'benchmark\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$SUITE_KEY" "$LANG_KEY" "$k" "$m" "$v" "$SM" "$note" "$cfg" >>"$PROG_ROWS"
    printf '%-20s %-4s %-7s %-7s %-7s %s\n' "$k" "$m" "$r1" "$r2" "$([ "$TIME_ANGLE" = 0 ] && echo - || echo "$r3")" "$v${why:+ -- $(echo "$why" | sed 's/^[; ]*//')}"
  done
  [ "$okboth" = 1 ] && BOTH=$((BOTH+1))
  if [ "$ORACLE_ARM" = 1 ] && [ "$gen_ok" = 1 ]; then
    o1=FAIL; o2=FAIL; o3=FAIL; owhy=""
    run1 "$T/$k.sbl.p" "" "${WRAPV[@]}" "$SBL" -bf "$f"; rc=$?
    if [ "$rc" = 0 ] && cmp -s "$T/$k.sbl.p.out" "$ref"; then o1=PASS; else owhy="process: rc=$rc$(cmp -s "$T/$k.sbl.p.out" "$ref" || echo ', output differs from .ref')"; fi
    run1 "$T/$k.sbl.i" "" "$SBL" -bf "$T/$k.iter.$EXT"; rc=$?; w="$(bench_ok "$T/$k.sbl.i.err" iter)"
    if [ "$rc" = 0 ] && cmp -s "$T/$k.sbl.i.out" "$ref" && [ -z "$w" ]; then o2=PASS; else owhy="$owhy; iter: rc=$rc${w:+, $w}"; fi
    TO="$T/$k.time.$EXT"   # the oracle's NS-TIME clock reads nanoseconds: a twin spelled in a port's unit is cut again in SPITBOL's
    [ "${#TUARG[@]}" -gt 0 ] && python3 "$GEN" "$f" --mode time --bud-ms "$BUD_MS" -o "$T/$k.time.sbl.$EXT" 2>/dev/null && TO="$T/$k.time.sbl.$EXT"
    run1 "$T/$k.sbl.t" "" "$SBL" -bf "$TO"; rc=$?; w="$(bench_ok "$T/$k.sbl.t.err" time)"
    if [ "$rc" = 0 ] && cmp -s "$T/$k.sbl.t.out" "$ref" && [ -z "$w" ]; then o3=PASS; else owhy="$owhy; time: rc=$rc${w:+, $w}"; fi
    grep -h '^BENCH_RUSAGE' "$T/$k.sbl.p.err" | sed "s/^/    scouting $k sbl: /"
    for x in i t; do grep -h '^BENCH mode=' "$T/$k.sbl.$x.err" | sed "s/^/    scouting $k sbl: /"; done
    printf '%-20s %-4s %-7s %-7s %-7s %s\n' "$k" sbl "$o1" "$o2" "$o3" "$([ "$o1$o2$o3" = PASSPASSPASS ] && echo PASS || echo "FAIL -- $(echo "$owhy" | sed 's/^[; ]*//')") (oracle arm, informational)"
  fi
done
LINE="SUITE_BOARD family=$SUITE_KEY total=$TOTAL shipped=$TOTAL all_pass=$BOTH all_n=$TOTAL m3_pass=${PASSN[m3]} m4_pass=${PASSN[m4]} angles=$ANGLES iter_n=$ITER_N bud_ms=$BUD_MS memory_declared=$HEAPD"
[ "$PORT" = 1 ] && LINE="$LINE engine=$(one_runner_engine) modes=m3"
echo
echo "$LINE"
[ -n "$NAMED" ] && echo "  not passing:$NAMED"
[ "$PORT" = 1 ] && echo "  tree: engine $(one_runner_port_tree) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)" || echo "  tree: SCRIP=$(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null)$(git -C "$HERE/../../SCRIP" diff --quiet 2>/dev/null || echo -dirty) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)$(git -C "$S4E/corpus" diff --quiet 2>/dev/null || echo -dirty) RT_OPT=-O0"
if [ "$IS_BOARD" = 0 ]; then
  echo "  population $BD is OUTSIDE the corpus tree -- not a board (CEO-547): graded, and no progress row and no suite row written"
else
  progress_append_rows_tsv "$PROG_ROWS" || echo "⚠ PROGRESS DB NOT UPDATED -- the board above stands, its per-program rows do not (reason above)" >&2
  if [ "$PORT" = 1 ]; then echo "  suite row: the $(one_runner_engine) engine writes no SCRIP row -- its row is $SUITE_KEY@$(one_runner_engine), assembled from these progress rows (CEO-1822), graded in m3 alone"; [ "$NOWRITE" = 0 ] && one_runner_port_publish "$SUITE_KEY@$(one_runner_engine)"; [ "$BOTH" = "$TOTAL" ] && exit 0 || exit 1; fi
  . "$HERE/lib_bench_write.sh" || refuse "lib_bench_write.sh unloadable -- the one rule for when a bench row publishes"
  read -r WRITE WRITE_WHY <<<"$(bench_row_writes "$(cd "$HERE/../.." && pwd)/corpus/benchmarks/snobol4" "$BD" "" "$NOWRITE")"
  echo "  row write: $([ "$WRITE" = 1 ] && echo yes || echo no) -- $WRITE_WHY"
  if [ "$WRITE" = 1 ]; then
    python3 "$HERE/util_score_row.py" write --lang "$LANG_KEY" --column bench-ref --measurer "${S4E_SEAT:-}" --text "$LINE" \
      || echo "⚠ SUITE ROW NOT WRITTEN -- util_score_row.py refused (reason above)"
  else
    echo "  suite row: not written ($WRITE_WHY; a whole-population pass publishes by default, the SNOBOL4 lane's seat publishes: util_score_row.py write --lang snobol4 --column bench-ref)"
  fi
fi
[ "$BOTH" = "$TOTAL" ] && exit 0 || exit 1
