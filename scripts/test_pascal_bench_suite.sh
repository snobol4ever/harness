#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" || exit 2
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# test_pascal_bench_suite.sh — THE PASCAL BENCHMARKS GRADED AS TESTS (row pascal-benchmarks-double-as-tests-ref-in-out-through-the-
# three-angle-harness-with-a-row-in-the-suite-grid; RULES.md § THE KERNEL CONVENTION, 2026-09-23 addendum, CEO-1221).
# Lon, verbatim: "The reason to force a benchmark to also be a test is to guarantee it is not vacuous." -- "The source of the benchmark
# is the apple-core of the test, the wrapper code can be added to do both the test and the measurements."
#
# POPULATION: every *.pas under corpus/benchmarks/pascal, by extension -- never a kernel list, so a kernel added later is graded the day
# it lands. Each carries a .ref cut from fpc -Miso that pins a value the kernel COMPUTES, and a .in wherever it reads input.
# THE CRITERION: a kernel passes a mode when EVERY run under all three angles prints exactly its .ref, and passes the row when it passes
# in BOTH modes (m3 --run; m4 --compile, linked against out/libscrip_rt.so, run as a process). The three angles, one wrapper each:
#   (1) PROCESS WRAPPER -- one run under tools/bench_rusage, the external stopwatch (it forks the target with stdout untouched and
#       reports on its own stderr, so the output diffed here is the kernel's own).
#   (2) FIXED ITERATIONS -- a kernel with a reps knob (its .in is one integer) is fed BENCH_ITER_N as its reps and runs once; a kernel
#       with a fixed workload (no knob: uplevel2, uplevel3, fbench) is run as a process BENCH_ITER_N times. Every run is diffed.
#   (3) FIXED TIME LIMIT -- runs repeat (reps doubling from 1 for a knob, the process repeated otherwise) until BENCH_TIME_LIMIT
#       seconds have elapsed; every run is diffed, and at least one always runs.
# ⭐ A REF CAN BE CHECKED UNDER A DIFFERENT REPS BECAUSE EVERY KERNEL'S PRINTED RESULT IS INDEPENDENT OF ITS REPS -- each repetition
# redoes the same work from the same start. That is what makes one REF serve all three angles; a kernel whose answer drifted with
# reps would fail angle 2 or 3 here, loudly, which is the non-vacuity check doing its job.
# ⛔ TIMING IS RECORDED, NOT PUBLISHED: each run's elapsed time goes into the per-run OUT directory, but no rate enters the grid until
# the quiet-box re-run (CEO-1219); this board's verdict is correctness only.
# OUT IS REF (Lon, in-chat to the ceo: "Oh. Yeah. OUT is really REF. My bad."; CEO-1222): a benchmark carries a .ref and a .in where
# it reads input, and no third file -- no .out, .std or .expected anywhere in the corpus. What this runner keeps of each run is scratch
# evidence, not a corpus file: <kernel>.<mode>.<angle>[.<n>].stdout plus its rusage line, in the run directory printed on the board.
set -u
GATE_NAME=test_pascal_bench_suite
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
B="$ROOT/corpus/benchmarks/pascal"
NOWRITE=0; [ "${1:-}" = --no-write ] && NOWRITE=1   # ⭐ PUBLISHING IS THE DEFAULT (ceo CEO-1302 (a), lib_bench_write.sh): a whole-population pass writes its row, a subset or --no-write never does; --write is still accepted and changes nothing
SCRIP="$HERE/../../SCRIP/scrip"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
ITER_N="${BENCH_ITER_N:-3}"
TIME_LIMIT="${BENCH_TIME_LIMIT:-2}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$B" ] || refuse "no benchmark corpus at $B"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT_DIR/libscrip_rt.so" || exit 2
. "$HERE/lib_progress.sh" 2>/dev/null || refuse "lib_progress.sh unloadable"
. "$HERE/lib_declared_arena.sh" 2>/dev/null || refuse "lib_declared_arena.sh unloadable -- the ONE reader of a program's declared -d/-s sidecars (CEO-1281)"
declare -a DECL_SW=()
WRAP="$HERE/../../SCRIP/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$HERE/../../SCRIP/tools/bench_rusage.c" || refuse "tools/bench_rusage failed to build -- angle 1 has no wrapper"
case "$ITER_N" in ''|*[!0-9]*|0) refuse "BENCH_ITER_N must be a positive integer (got '$ITER_N')";; esac
case "$TIME_LIMIT" in ''|*[!0-9]*|0) refuse "BENCH_TIME_LIMIT must be a positive whole number of seconds (got '$TIME_LIMIT')";; esac
OUTDIR="${BENCH_OUT_DIR:-$(mktemp -d -t pascal_bench_runs.XXXXXX)}"; mkdir -p "$OUTDIR" || refuse "cannot create $OUTDIR"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PROG_ROWS="$TMP/progress.tsv"; : >"$PROG_ROWS"
mapfile -t KERNELS < <(find "$B" -maxdepth 1 -type f -name '*.pas' -printf '%f\n' | sed 's/\.pas$//' | sort)
# ⭐ THE ROUND ROBIN'S SEAM AND THE LIST MODE (the coo 2026-10-23, the ceo's seam census; as test_raku_bench_suite.sh, lib_rr.sh): under
# S4E_CHUNK=entry:<kernel>[,...] only those kernels are graded, their rows appended, no suite row written (rr_end); under S4E_LIST=1 the
# population is printed (RR_POP, the key its progress rows carry) and nothing graded -- util_score_row.py from-progress reads it (rr_list)
. "$HERE/lib_rr.sh" && rr_load "$B" || exit 2
rr_list ${KERNELS[@]+"${KERNELS[@]}"}
if rr_selected; then _ks=(); for k in "${KERNELS[@]}"; do rr_admits "$k" && _ks+=("$k"); done; KERNELS=(${_ks[@]+"${_ks[@]}"}); fi
[ "${#KERNELS[@]}" -gt 0 ] || refuse "no *.pas under $B -- a population of zero is not a green board"
now() { date +%s.%N; }
# run_kernel <mode> <kernel> <stdin-file> <out-file> [wrap] -- one run; prints nothing, returns the run's rc. m4 runs the prebuilt binary.
run_kernel() {
  local m="$1" k="$2" in="$3" out="$4" w="${5:-}"
  # the kernel's declared heap and stack ride its command line as -d/-s switches in both modes (its .heap/.stack sidecars; CEO-1281)
  if [ "$m" = m3 ]; then ( cd "$TMP" && "$TIMEOUT_RETRY" 300s $w "$SCRIP" --run "${DECL_SW[@]}" "$B/$k.pas" <"$in" >"$out" 2>"$out.err" )
  else ( cd "$TMP" && "$TIMEOUT_RETRY" 300s $w "$TMP/$k.m4" "${DECL_SW[@]}" <"$in" >"$out" 2>"$out.err" ); fi
}
# same_as_ref <out-file> <kernel> -- byte-for-byte after the shell's own trailing-newline trim, the rule every Pascal board uses.
same_as_ref() { [ "$(cat "$1")" = "$(cat "$B/$2.ref")" ]; }
# failed <rc> -- the reason one run failed: a non-zero exit, or a clean exit whose output is not the .ref.
failed() { [ "$1" = 0 ] && echo "output differs from .ref" || echo "rc=$1"; }
declare -A PASSN; PASSN[m3]=0; PASSN[m4]=0; BOTH=0; TOTAL=0; NAMED=""
printf '%-10s %-4s %-7s %-7s %-7s %s\n' kernel mode wrap iter time verdict
for k in "${KERNELS[@]}"; do
  TOTAL=$((TOTAL+1)); okboth=1
  if [ ! -s "$B/$k.ref" ]; then
    for m in m3 m4; do printf 'benchmark\tpascal-bench-ref\tpascal\t%s\t%s\tFAIL\t0\tno-ref\n' "$k" "$m" >>"$PROG_ROWS"; done
    printf '%-10s %-4s %s\n' "$k" "both" "FAIL no .ref -- a benchmark without a REF cannot be graded, and is counted, not skipped"; NAMED="$NAMED $k(no-ref)"; continue
  fi
  in="$B/$k.in"; [ -f "$in" ] || in=/dev/null
  DECL_SW=(); dw=$(declared_switches_beside "$B/$k.pas") || refuse "$k: a .heap or .stack sidecar the reader refuses (it said why above)"; [ -n "$dw" ] && read -r -a DECL_SW <<<"$dw"
  knob=0; if [ "$in" != /dev/null ] && [ "$(grep -c . "$in")" = 1 ] && grep -qE '^[[:space:]]*[0-9]+[[:space:]]*$' "$in"; then knob=1; fi
  tc="$(progress_clock)"
  m4ok=1; ( cd "$TMP" && "$TIMEOUT_RETRY" 300s "$SCRIP" --compile --out="$TMP/$k.s" "$B/$k.pas" </dev/null >"$TMP/$k.cc.err" 2>&1 ) \
    && ( cd "$TMP" && cc -m64 -no-pie "$k.s" -o "$k.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >>"$TMP/$k.cc.err" 2>&1 ) || m4ok=0
  cs="$(progress_secs_since "$tc")"
  for m in m3 m4; do
    a1=FAIL; a2=FAIL; a3=FAIL; why=""; tm="$(progress_clock)"
    if [ "$m" = m4 ] && [ "$m4ok" = 0 ]; then why="m4 compile/link failed: $(head -c 120 "$TMP/$k.cc.err" | tr '\n' ' ')"
    else
      o="$OUTDIR/$k.$m.wrap.stdout"; run_kernel "$m" "$k" "$in" "$o" "$WRAP"; rc=$?
      grep -h '^BENCH_RUSAGE:' "$o.err" >"$o.rusage" 2>/dev/null
      if [ "$rc" = 0 ] && same_as_ref "$o" "$k"; then a1=PASS; else why="wrap: $(failed "$rc")"; fi
      a2=PASS
      if [ "$knob" = 1 ]; then
        printf '%s\n' "$ITER_N" >"$TMP/reps"; o="$OUTDIR/$k.$m.iter.stdout"; run_kernel "$m" "$k" "$TMP/reps" "$o"; rc=$?
        { [ "$rc" = 0 ] && same_as_ref "$o" "$k"; } || { a2=FAIL; why="$why; iter(reps=$ITER_N): $(failed "$rc")"; }
      else
        for n in $(seq 1 "$ITER_N"); do o="$OUTDIR/$k.$m.iter.$n.stdout"; run_kernel "$m" "$k" "$in" "$o"; rc=$?
          { [ "$rc" = 0 ] && same_as_ref "$o" "$k"; } || { a2=FAIL; why="$why; iter(run $n of $ITER_N): $(failed "$rc")"; break; }; done
      fi
      a3=PASS; t0=$(now); reps=1; n=0
      while :; do
        n=$((n+1)); o="$OUTDIR/$k.$m.time.$n.stdout"
        if [ "$knob" = 1 ]; then printf '%s\n' "$reps" >"$TMP/reps"; run_kernel "$m" "$k" "$TMP/reps" "$o"; else run_kernel "$m" "$k" "$in" "$o"; fi; rc=$?
        { [ "$rc" = 0 ] && same_as_ref "$o" "$k"; } || { a3=FAIL; why="$why; time(run $n, reps=$reps): $(failed "$rc")"; break; }
        [ "$(echo "$(now) - $t0 >= $TIME_LIMIT" | bc)" = 1 ] && break
        [ "$knob" = 1 ] && reps=$((reps*2)); [ "$n" -ge 64 ] && break
      done
      printf '%s\n' "$n runs, last reps=$reps, $(echo "$(now) - $t0" | bc) s" >"$OUTDIR/$k.$m.time.summary"
    fi
    if [ "$a1$a2$a3" = PASSPASSPASS ]; then v=PASS; PASSN[$m]=$((PASSN[$m]+1)); note="ref-under-three-angles"
    else v=FAIL; okboth=0; note="$(echo "$why" | sed 's/^[; ]*//' | tr '\t' ' ')"; NAMED="$NAMED $k.$m"; fi
    # the row's secs: this mode's three angles, and for m4 the compile and link before them (CEO-1676 (c))
    s="$(progress_secs_since "$tm")"; [ "$m" = m4 ] && s="$(progress_secs_sum "$s" "$cs")"
    printf 'benchmark\tpascal-bench-ref\tpascal\t%s\t%s\t%s\t%s\t%s\n' "$k" "$m" "$v" "$s" "$note" >>"$PROG_ROWS"
    printf '%-10s %-4s %-7s %-7s %-7s %s\n' "$k" "$m" "$a1" "$a2" "$a3" "$v${why:+ -- $why}"
  done
  [ "$okboth" = 1 ] && BOTH=$((BOTH+1))
done
echo
echo "PASCAL_BENCH_BOARD total=$TOTAL both_pass=$BOTH m3_pass=${PASSN[m3]} m4_pass=${PASSN[m4]} (three angles each: process wrapper, fixed iterations N=$ITER_N, fixed time limit ${TIME_LIMIT}s; every run diffed against its .ref)"
[ -n "$NAMED" ] && echo "  not passing:$NAMED"
echo "  evidence: every run's stdout and rusage line kept under $OUTDIR (scratch, not a corpus file -- OUT is REF, CEO-1222)"
echo "  tree: SCRIP=$(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null)$(git -C "$HERE/../../SCRIP" diff --quiet 2>/dev/null || echo -dirty) corpus=$(git -C "$ROOT/corpus" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT/corpus" diff --quiet 2>/dev/null || echo -dirty) RT_OPT=-O0"
# ⭐ PUBLISHING: the suite-table row is PasBench, key pascal-bench-ref -- the SAME name as this runner's progress suite, on purpose
# (coo 2026-09-23: every key-to-DB map falls back to the key itself, so the bench rows need no map entry anywhere). The rows are
# appended FIRST because util_score_row.py's CEO-750 cross-check reads the pascal-bench-ref rows on the tree the write stamps; the
# write then lands the SUITES.tsv row and its SCORE.md line and no grid cell (the grid's B cell is the timing cell, which waits for
# the quiet box). The writer reads all_pass/all_n from the board line BY NAME (CEO-827). Bookkeeping never turns a real
# measurement into a red board, and never fails quietly: both steps say so when they do not land.
if [ -s "$PROG_ROWS" ]; then
  progress_append_rows_tsv "$PROG_ROWS" || echo "⚠ PROGRESS DB NOT UPDATED -- the board above stands, its per-program rows do not (reason above)" >&2
fi
LINE="SUITE_BOARD family=pascal-bench-ref total=$TOTAL all_pass=$BOTH all_n=$TOTAL m3_pass=${PASSN[m3]} m4_pass=${PASSN[m4]} angles=wrap,iter,time"
echo "$LINE"
rr_selected && { rr_end pascal-bench-ref; [ "$BOTH" = "$TOTAL" ] && exit 0 || exit 1; }
. "$HERE/lib_bench_write.sh" || refuse "lib_bench_write.sh unloadable -- the one rule for when a bench row publishes"
read -r WRITE WRITE_WHY <<<"$(bench_row_writes "$(cd "$HERE/../.." && pwd)/corpus/benchmarks/pascal" "$B" "" "$NOWRITE")"
echo "  row write: $([ "$WRITE" = 1 ] && echo yes || echo no) -- $WRITE_WHY"
if [ "$WRITE" = 1 ]; then
  python3 "$HERE/util_score_row.py" write --lang pascal --column bench-ref --measurer "${S4E_SEAT:-}" --text "$LINE" 2>&1 | sed 's/^/    /'
fi
[ "$BOTH" = "$TOTAL" ] && exit 0 || exit 1
