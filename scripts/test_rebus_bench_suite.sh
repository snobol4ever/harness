#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${BENCH_REBUS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/corpus/benchmarks/rebus}" || exit 2
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# test_rebus_bench_suite.sh [--no-write] -- THE REBUS BENCHMARKS GRADED AS TESTS: every program under corpus/benchmarks/rebus, both modes,
# all three angles, its REF checked on every run (row rebus-benchmarks-double-as-tests-ref-in-out-through-the-three-angle-harness-with-
# a-row-in-the-suite-grid; built by the coo on CEO-1227 to the contract of instruments-benchmarks-enter-the-suite-grid-..., COO-164).
# Lon 2026-09-23, verbatim: "The reason to force a benchmark to also be a test is to guarantee it is not vacuous." -- "The source of
# the benchmark is the apple-core of the test, the wrapper code can be added to do both the test and the measurements."
#
# POPULATION: every *.reb in the benchmark tree, by extension -- never a kernel list, so a kernel added later is graded the day it
# lands. Each REF is DERIVED (Rebus has no independent implementation; CEO-607, the .derivation beside it, re-proved by
# test_gate_rebus_derived_refs_match_their_rival_oracle.sh) and pins a value the kernel COMPUTES. No kernel reads input, so no IN.
# THE CRITERION: a program passes a mode when every angle prints exactly its .ref with rc 0, and passes the row in BOTH modes
# (m3 --run; m4 --compile, linked against out/libscrip_rt.so, run as a process). The three angles:
#   (1) PROCESS WRAPPER -- the PRISTINE kernel once under tools/bench_rusage, the external stopwatch (stdout untouched).
#   (2) FIXED ITERATIONS -- the program bench_wrap_rebus.py GENERATES from the kernel (--mode iter): the test once, then BENCH_ITER_N
#       quiet repetitions; its BENCH line must read iters=N, mismatched=0, and value= the .ref.
#   (3) FIXED TIME LIMIT -- the same generator (--mode time): quiet repetitions until BENCH_BUD_MS is spent; at least one, mismatched=0,
#       value= the .ref. A wrapper run with no BENCH line is UNMEASURED, and that is a FAIL here, never a pass.
# MEMORY: a kernel that needs more than the shipped arena or stack declares it beside itself -- NAME.heap and NAME.stack, one line
# NAME TAB KB each -- read through lib_declared_arena.sh (declared_arena_kb_beside, declared_stack_kb_beside: the harness's own
# readers, CEO-1171's floors), exported for THAT program only (SCRIP_HEAP_KB, SCRIP_STACK; CEO-1225).
# ⛔ TIMING IS SCOUTING, NOT PUBLISHED: the BENCH and BENCH_RUSAGE numbers are printed per run; no rate enters the grid until the
# quiet-box re-run (CEO-1219). CEO-1222: REF and IN only -- each run's stdout lives in a temp dir that is deleted.
# PUBLISH: the board is the Rebus lane's (MODE LANES rebus=ceo). One progress row per program per mode (class benchmark, suite
# rebus-bench-ref, config declared) is appended when the population is the corpus tree; a whole-population pass then calls util_score_row.py write by default (CEO-1302 (a), --no-write opts out)
# --lang rebus --column bench-ref, whose lane check admits only the lane's seat. A population OUTSIDE the corpus tree (a fixture,
# BENCH_REBUS_DIR) is not a board (CEO-547): it is graded, and nothing is appended or written.
# EXIT 0 every program PASS; 1 any program not PASS; 2 REFUSED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
BD="${BENCH_REBUS_DIR:-$S4E/corpus/benchmarks/rebus}"
GATE_NAME=test_rebus_bench_suite
SCRIP="$HERE/../../SCRIP/scrip"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
ITER_N="${BENCH_ITER_N:-3}"
BUD_MS="${BENCH_BUD_MS:-200}"
NOWRITE=0; [ "${1:-}" = --no-write ] && NOWRITE=1   # ⭐ PUBLISHING IS THE DEFAULT (ceo CEO-1302 (a), lib_bench_write.sh): a whole-population pass writes its row, a subset or --no-write never does; --write is still accepted and changes nothing
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$BD" ] || refuse "no benchmark tree at $BD"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT_DIR/libscrip_rt.so" || exit 2
. "$HERE/lib_declared_arena.sh" 2>/dev/null || refuse "lib_declared_arena.sh unloadable -- the one reader of a declared arena"
. "$HERE/lib_progress.sh" 2>/dev/null || refuse "lib_progress.sh unloadable"
GEN="$HERE/bench_wrap_rebus.py"; [ -f "$GEN" ] || refuse "no wrapper generator at $GEN -- angles 2 and 3 have nothing to run"
WRAP="$HERE/../../SCRIP/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O0 -o "$WRAP" "$HERE/../../SCRIP/tools/bench_rusage.c" || refuse "tools/bench_rusage failed to build -- angle 1 has no wrapper"
case "$ITER_N" in ''|*[!0-9]*|0) refuse "BENCH_ITER_N must be a positive integer (got '$ITER_N')";; esac
case "$BUD_MS" in ''|*[!0-9]*|0) refuse "BENCH_BUD_MS must be a positive whole number of milliseconds (got '$BUD_MS')";; esac
IS_BOARD=0; one_runner_suite_is_a_board "$BD" && IS_BOARD=1
mapfile -t KERNELS < <(find "$BD" -maxdepth 1 -type f -name '*.reb' -printf '%f\n' | sed 's/\.reb$//' | LC_ALL=C sort)
[ "${#KERNELS[@]}" -gt 0 ] || refuse "no *.reb under $BD -- a population of zero is not a green board"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PROG_ROWS="$T/progress.tsv"; : >"$PROG_ROWS"
# run1 <out-prefix> <heap-kb|''> <cmd...> -- one run, stdout/stderr kept under the prefix; returns the run's rc
run1() {
  local o="$1" kb="$2"; shift 2
  ( cd "$T" && [ -n "$kb" ] && export SCRIP_HEAP_CAP_KB="$kb" && unset SCRIP_HEAP_MB SCRIP_HEAP_KB; [ -n "${st:-}" ] && export SCRIP_STACK="${st}k"
    "$TIMEOUT_RETRY" 300s "$@" </dev/null >"$o.out" 2>"$o.err" )
}
# build4 <src.reb> <bin> -- the mode-4 binary of one program; returns 0 when it links
build4() {
  ( cd "$T" && "$TIMEOUT_RETRY" 300s "$SCRIP" --compile "$1" -o "$2.s" </dev/null >"$2.cc" 2>&1 ) \
    && ( cd "$T" && cc -m64 -no-pie "$2.s" -o "$2" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >>"$2.cc" 2>&1 )
}
# bench_ok <err-file> <mode> <ref-value> -- the generated wrapper's BENCH line holds: its mode, its iteration count, no mismatch, the ref's value
bench_ok() {
  local b; b="$(grep -m1 '^BENCH mode=' "$1")" || { echo "no BENCH line (UNMEASURED)"; return 1; }
  case "$b" in *"mode=$2 "*) ;; *) echo "BENCH line of the wrong mode: $b"; return 1;; esac
  local it mm val; it="$(sed -n 's/.* iters=\([0-9]*\) .*/\1/p' <<<"$b")"; mm="$(sed -n 's/.* mismatched=\([0-9]*\) .*/\1/p' <<<"$b")"; val="${b##* value=}"
  [ "$2" = iter ] && [ "$it" != "$ITER_N" ] && { echo "iters=$it, not the $ITER_N asked for"; return 1; }
  [ "${it:-0}" -ge 1 ] || { echo "iters=${it:-?}: no repetition ran"; return 1; }
  [ "$mm" = 0 ] || { echo "mismatched=${mm:-?}: a repetition computed another value"; return 1; }
  [ "$val" = "$3" ] || { echo "value=$val, the ref reads $3"; return 1; }
  return 0
}
printf '%-16s %-4s %-7s %-7s %-7s %s\n' kernel mode process iter time verdict
declare -A PASSN; PASSN[m3]=0; PASSN[m4]=0; BOTH=0; TOTAL=0; NAMED=""; HEAPD=0
for k in "${KERNELS[@]}"; do
  TOTAL=$((TOTAL+1)); f="$BD/$k.reb"; ref="$BD/$k.ref"
  kb="$(declared_arena_kb_beside "$f")" || refuse "$k: its .heap sidecar is refused (the reader said why above)"
  st="$(declared_stack_kb_beside "$f")" || refuse "$k: its .stack sidecar is refused (the reader said why above)"
  cfg="shipped"; [ -n "$kb" ] && { cfg="SCRIP_HEAP_CAP_KB=$kb"; HEAPD=$((HEAPD+1)); }
  [ -n "$st" ] && { cfg="$([ "$cfg" = shipped ] || printf '%s,' "$cfg")SCRIP_STACK=${st}k"; HEAPD=$((HEAPD+1)); }
  if [ ! -s "$ref" ]; then
    for m in m3 m4; do printf 'benchmark\trebus-bench-ref\trebus\t%s\t%s\tFAIL\t0\tno-ref\t%s\n' "$k" "$m" "$cfg" >>"$PROG_ROWS"; done
    printf '%-16s %-4s %s\n' "$k" both "FAIL no .ref -- a benchmark without a REF cannot be graded, and is counted, not skipped"; NAMED="$NAMED $k(no-ref)"; continue
  fi
  want="$(head -1 "$ref")"
  gen_ok=1
  for a in iter time; do python3 "$GEN" "$f" --mode "$a" --n "$ITER_N" --bud-ms "$BUD_MS" -o "$T/$k.$a.reb" 2>"$T/$k.$a.gen" || gen_ok=0; done
  okboth=1
  for m in m3 m4; do
    _tm="$(progress_clock)"   # the mode's own wall for its row: its three angles, and in m4 their compile and link (CEO-1676 (c))
    r1=FAIL; r2=FAIL; r3=FAIL; why=""
    if [ "$gen_ok" = 0 ]; then why="the wrapper generator REFUSED: $(head -c 160 "$T/$k.iter.gen" "$T/$k.time.gen" 2>/dev/null | tr '\n' ' ')"
    else
      if [ "$m" = m3 ]; then P=("$SCRIP" --run "$f"); I=("$SCRIP" --run "$T/$k.iter.reb"); TM=("$SCRIP" --run "$T/$k.time.reb")
      else
        if build4 "$f" "$T/$k.p4" && build4 "$T/$k.iter.reb" "$T/$k.i4" && build4 "$T/$k.time.reb" "$T/$k.t4"; then P=("$T/$k.p4"); I=("$T/$k.i4"); TM=("$T/$k.t4")
        else why="m4 compile/link failed: $(cat "$T/$k.p4.cc" "$T/$k.i4.cc" "$T/$k.t4.cc" 2>/dev/null | head -c 160 | tr '\n' ' ')"; fi
      fi
      if [ -z "$why" ]; then
        run1 "$T/$k.$m.p" "$kb" "$WRAP" "${P[@]}"; rc=$?
        if [ "$rc" = 0 ] && cmp -s "$T/$k.$m.p.out" "$ref"; then r1=PASS; else why="process: rc=$rc$(cmp -s "$T/$k.$m.p.out" "$ref" || echo ', output differs from .ref')"; fi
        run1 "$T/$k.$m.i" "$kb" "${I[@]}"; rc=$?; w="$(bench_ok "$T/$k.$m.i.err" iter "$want")"
        if [ "$rc" = 0 ] && cmp -s "$T/$k.$m.i.out" "$ref" && [ -z "$w" ]; then r2=PASS; else why="$why; iter: rc=$rc$(cmp -s "$T/$k.$m.i.out" "$ref" || echo ', stdout differs from .ref')${w:+, $w}"; fi
        run1 "$T/$k.$m.t" "$kb" "${TM[@]}"; rc=$?; w="$(bench_ok "$T/$k.$m.t.err" time "$want")"
        if [ "$rc" = 0 ] && cmp -s "$T/$k.$m.t.out" "$ref" && [ -z "$w" ]; then r3=PASS; else why="$why; time: rc=$rc$(cmp -s "$T/$k.$m.t.out" "$ref" || echo ', stdout differs from .ref')${w:+, $w}"; fi
        for x in i t; do grep -h '^BENCH mode=' "$T/$k.$m.$x.err" | sed "s/^/    scouting $k $m: /"; done
      fi
    fi
    if [ "$r1$r2$r3" = PASSPASSPASS ]; then v=PASS; PASSN[$m]=$((PASSN[$m]+1)); note="ref-under-three-angles"
    # a wrapper the generator refused is no grade of the program: REFUSE, could not measure, never FAIL (the coo 2026-10-22, COO-396: RakBench's four
    # 10-15 refusals read FAIL in the red lists the cto was sent)
    else v=FAIL; [ "$gen_ok" = 0 ] && v=REFUSE; okboth=0; note="$(echo "$why" | sed 's/^[; ]*//' | tr '\t' ' ')"; NAMED="$NAMED $k.$m$([ "$v" = REFUSE ] && echo "(refused)")"; fi
    SM="$(progress_secs_since "$_tm")"
    printf 'benchmark\trebus-bench-ref\trebus\t%s\t%s\t%s\t%s\t%s\t%s\n' "$k" "$m" "$v" "$SM" "$note" "$cfg" >>"$PROG_ROWS"
    printf '%-16s %-4s %-7s %-7s %-7s %s\n' "$k" "$m" "$r1" "$r2" "$r3" "$v${why:+ -- $(echo "$why" | sed 's/^[; ]*//')}"
  done
  [ "$okboth" = 1 ] && BOTH=$((BOTH+1))
done
LINE="SUITE_BOARD family=rebus-bench-ref total=$TOTAL shipped=$TOTAL all_pass=$BOTH all_n=$TOTAL m3_pass=${PASSN[m3]} m4_pass=${PASSN[m4]} angles=process,iter,time iter_n=$ITER_N bud_ms=$BUD_MS memory_declared=$HEAPD"
echo
echo "$LINE"
[ -n "$NAMED" ] && echo "  not passing:$NAMED"
echo "  tree: SCRIP=$(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null)$(git -C "$HERE/../../SCRIP" diff --quiet 2>/dev/null || echo -dirty) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)$(git -C "$S4E/corpus" diff --quiet 2>/dev/null || echo -dirty) RT_OPT=-O0"
if [ "$IS_BOARD" = 0 ]; then
  echo "  population $BD is OUTSIDE the corpus tree -- not a board (CEO-547): graded, and no progress row and no suite row written"
else
  progress_append_rows_tsv "$PROG_ROWS" || echo "⚠ PROGRESS DB NOT UPDATED -- the board above stands, its per-program rows do not (reason above)" >&2
  . "$HERE/lib_bench_write.sh" || refuse "lib_bench_write.sh unloadable -- the one rule for when a bench row publishes"
  read -r WRITE WRITE_WHY <<<"$(bench_row_writes "$(cd "$HERE/../.." && pwd)/corpus/benchmarks/rebus" "$BD" "" "$NOWRITE")"
  echo "  row write: $([ "$WRITE" = 1 ] && echo yes || echo no) -- $WRITE_WHY"
  if [ "$WRITE" = 1 ]; then
    python3 "$HERE/util_score_row.py" write --lang rebus --column bench-ref --measurer "${S4E_SEAT:-}" --text "$LINE" \
      || echo "⚠ SUITE ROW NOT WRITTEN -- util_score_row.py refused (reason above)"
  else
    echo "  suite row: not written ($WRITE_WHY; a whole-population pass publishes by default, the Rebus lane's seat publishes: util_score_row.py write --lang rebus --column bench-ref)"
  fi
fi
[ "$BOTH" = "$TOTAL" ] && exit 0 || exit 1
