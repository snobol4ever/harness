#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${BENCH_RAKU_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/corpus/benchmarks/raku}" || exit 2
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# test_raku_bench_suite.sh [--no-write] -- THE RAKU BENCHMARKS GRADED AS TESTS: every kernel under corpus/benchmarks/raku, both modes,
# all three angles, its REF checked on every run (the RakBench row of SCORE.md THE SUITE TABLE; Lon 2026-09-24 14:2x, in-chat to
# the ceo: create a runner for RakBench; built by the ceo on the shape of test_rebus_bench_suite.sh, the coo's COO-164 contract).
# Lon 2026-09-23, verbatim: "The reason to force a benchmark to also be a test is to guarantee it is not vacuous."
#
# POPULATION: every *.raku directly under the benchmark tree, by extension -- never a kernel list. Each kernel's .ref is the
# program's real output, cut from rakudo (the roast/rakudo oracle, RULES.md section Oracles). No kernel reads input, so no IN.
# THE CRITERION: a kernel passes a mode when every angle prints exactly its .ref with rc 0, and passes the row in BOTH modes
# (m3 --run; m4 --compile, assembled and linked against out/libscrip_rt.so the way corpus_suite_harness.py links, run as a process).
#   (1) PROCESS WRAPPER -- the PRISTINE kernel once under tools/bench_rusage, the external stopwatch (stdout untouched).
#   (2) FIXED ITERATIONS -- the program bench_wrap_raku.py GENERATES from the kernel (--mode iter): the test once (its stdout must
#       be the .ref), then one warm-up and BENCH_ITER_N quiet repetitions whose output is captured instead of printed; its BENCH
#       line must read iters=N, mismatched=0, and value= the .ref's own character count (a capture that reads empty is a loss).
#   (3) FIXED TIME LIMIT -- the same generator (--mode time): quiet repetitions until BENCH_BUD_MS is spent; at least one,
#       mismatched=0, value= the .ref's count. A wrapper run with no BENCH line is UNMEASURED, and that is a FAIL here.
# MEMORY: NAME.heap and NAME.stack sidecars beside a kernel, read through lib_declared_arena.sh, exported for THAT program only.
# ⛔ TIMING IS SCOUTING, NOT PUBLISHED: the BENCH and BENCH_RUSAGE numbers are printed per run; bench_triangulate_raku.sh is the
# timing instrument. CEO-1222: REF only -- each run's stdout lives in a temp dir that is deleted.
# PUBLISH: the board is the Raku lane's (MODE LANES raku=hq_raku). One progress row per kernel per mode (class benchmark, suite
# raku-bench-ref, config declared) is appended when the population is the corpus tree; a whole-population pass then calls util_score_row.py write by default (CEO-1302 (a), --no-write opts out)
# --lang raku --column bench-ref. A population OUTSIDE the corpus tree (BENCH_RAKU_DIR) is not a board (CEO-547).
# EXIT 0 every kernel PASS; 1 any kernel not PASS; 2 REFUSED.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
BD="${BENCH_RAKU_DIR:-$S4E/corpus/benchmarks/raku}"
GATE_NAME=test_raku_bench_suite
LANG_KEY=raku; SUITE_KEY=raku-bench-ref; EXT=raku
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
GEN="$HERE/bench_wrap_raku.py"; [ -f "$GEN" ] || refuse "no wrapper generator at $GEN -- angles 2 and 3 have nothing to run"
WRAP="$HERE/../../SCRIP/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O0 -o "$WRAP" "$HERE/../../SCRIP/tools/bench_rusage.c" || refuse "tools/bench_rusage failed to build -- angle 1 has no wrapper"
case "$ITER_N" in ''|*[!0-9]*|0) refuse "BENCH_ITER_N must be a positive integer (got '$ITER_N')";; esac
case "$BUD_MS" in ''|*[!0-9]*|0) refuse "BENCH_BUD_MS must be a positive whole number of milliseconds (got '$BUD_MS')";; esac
# ⭐ BENCH_ANGLES CHOOSES THE ANGLES GRADED (Lon 2026-10-08, in-chat to the ceo: "Why does RakBench take so long to run? Are the benchmarks
# parameters tunable so that could be reduced?"; CEO-1564): default process,iter,time; the coo's standing loop grades the row with
# BENCH_ANGLES=process -- the pristine kernel once per mode against its .ref, the row's verdict -- and the three angles run on the publish
# cadence. An angle not chosen is not generated, built or run, reads "-" in its column, and the board line names the angles graded.
ANGLES="${BENCH_ANGLES:-process,iter,time}"; DO_P=0; DO_I=0; DO_T=0
IFS=',' read -r -a _angs <<<"$ANGLES"
for _a in "${_angs[@]}"; do case "$_a" in process) DO_P=1;; iter) DO_I=1;; time) DO_T=1;; *) refuse "BENCH_ANGLES names '$_a' -- process, iter and time are the angles (got '$ANGLES')";; esac; done
[ "$DO_P$DO_I$DO_T" != 000 ] || refuse "BENCH_ANGLES names no angle (got '$ANGLES')"
[ "$((DO_P+DO_I+DO_T))" = "${#_angs[@]}" ] || refuse "BENCH_ANGLES names an angle twice (got '$ANGLES')"
ANGLES="$( { [ $DO_P = 1 ] && printf 'process,'; [ $DO_I = 1 ] && printf 'iter,'; [ $DO_T = 1 ] && printf 'time,'; } | sed 's/,$//')"
IS_BOARD=0; one_runner_suite_is_a_board "$BD" && IS_BOARD=1
mapfile -t KERNELS < <(find "$BD" -maxdepth 1 -type f -name "*.$EXT" -printf '%f\n' | sed "s/\.$EXT\$//" | LC_ALL=C sort)
[ "${#KERNELS[@]}" -gt 0 ] || refuse "no *.$EXT under $BD -- a population of zero is not a green board"
# ⭐ THE ROUND ROBIN'S SEAM (ceo CEO-1806/1812, as test_prolog_bench_suite.sh): under S4E_CHUNK=entry:<kernel>[,...] only those kernels are graded,
# their rows appended, and no suite row is written (rr_end) -- one program at a time (Lon 2026-10-23, CEO-1926)
. "$HERE/lib_rr.sh" && rr_load "$BD" || exit 2
if rr_selected; then _ks=(); for k in "${KERNELS[@]}"; do rr_admits "$k" && _ks+=("$k"); done; KERNELS=(${_ks[@]+"${_ks[@]}"}); fi
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# ⭐ A WRAPPER READS ITS KERNEL'S DATA FROM ITS OWN DIRECTORY (cfo 2026-10-23, CEO-1926): parse-json and parse-json-no-obj-creation open
# $*PROGRAM.parent.add('panda-projects.json'); the pristine kernel runs from $BD and finds it, but the iter and time twins are generated into $T and
# died rc 1 "Failed to open file" on every reading since the angles ran. Every data file of the tree that a kernel names is copied beside them.
for _d in "$BD"/*; do case "${_d##*/}" in *."$EXT"|*.ref|*.heap|*.stack|*.ast|*.s|*.tsv|*.md|LICENSE*) continue;; esac
  [ -f "$_d" ] && grep -lqF -- "${_d##*/}" "$BD"/*."$EXT" && cp "$_d" "$T/"; done
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
# bench_ok <err-file> <mode> <ref-chars> -- the wrapper's BENCH line holds: its mode, its iteration count, no mismatch, the ref's count
bench_ok() {
  local b; b="$(grep -m1 '^BENCH mode=' "$1")" || { echo "no BENCH line (UNMEASURED)"; return 1; }
  case "$b" in *"mode=$2 "*) ;; *) echo "BENCH line of the wrong mode: $b"; return 1;; esac
  local it mm val; it="$(sed -n 's/.* iters=\([0-9]*\) .*/\1/p' <<<"$b")"; mm="$(sed -n 's/.* mismatched=\([0-9]*\) .*/\1/p' <<<"$b")"; val="${b##* value=}"
  [ "$2" = iter ] && [ "$it" != "$ITER_N" ] && { echo "iters=$it, not the $ITER_N asked for"; return 1; }
  [ "${it:-0}" -ge 1 ] || { echo "iters=${it:-?}: no repetition ran"; return 1; }
  [ "$mm" = 0 ] || { echo "mismatched=${mm:-?}: a repetition computed another value"; return 1; }
  [ "$val" = "$3" ] || { echo "value=$val characters captured, the .ref has $3 (an empty capture is a lost output, not a pass)"; return 1; }
  return 0
}
# ⭐ OUTSIDE.tsv NAMES A KERNEL OUT OF THE RUN (Lon 2026-10-10, in-chat to the cto, verbatim: "Fix RakBench not to take 1 hour." then "Well then,
# just remove the four slow ones and keep the rest."; the cto's measurement: four raku-bench whole programs, 29-52 s a run each, were 341 of the
# 399 s the 84 kernels take on the process angle alone, and under three angles the hour): kernel<TAB>CLASS<TAB>evidence, OUTSIDE_SLOW the one
# class. Unlike the Prolog bench's OUTSIDE_CLPFD (graded, out of the denominator) a slow kernel is NOT generated, built or run here -- that is
# the whole point -- it stays vendored for the gates that witness with it and for the publish-cadence bench grid, is named on its own line, and
# leaves total/all_n (shipped = total + excluded, the row's Excl column); a malformed row, another class, no evidence or a name that is no
# kernel refuses rc 2 before anything is graded.
declare -A OUTS; NOUT=0; OUTN=""
if [ -f "$BD/OUTSIDE.tsv" ]; then
  while IFS=$'\t' read -r _ok _ocls _oev || [ -n "$_ok" ]; do
    case "$_ok" in ''|'#'*) continue ;; esac
    [ "$_ocls" = OUTSIDE_SLOW ] || refuse "OUTSIDE.tsv names $_ok with class '$_ocls' -- OUTSIDE_SLOW is the one class (Lon 2026-10-10)"
    [ -n "${_oev// /}" ] || refuse "OUTSIDE.tsv names $_ok with no evidence -- an exclusion with no measurement is an opinion"
    [ -f "$BD/$_ok.$EXT" ] || refuse "OUTSIDE.tsv names $_ok, which is no kernel under $BD"
    OUTS[$_ok]="$_ocls"
  done < "$BD/OUTSIDE.tsv"
fi
printf '%-28s %-4s %-7s %-7s %-7s %s\n' kernel mode process iter time verdict
declare -A PASSN; PASSN[m3]=0; PASSN[m4]=0; BOTH=0; TOTAL=0; NAMED=""; HEAPD=0
for k in "${KERNELS[@]}"; do
  if [ -n "${OUTS[$k]:-}" ]; then NOUT=$((NOUT+1)); OUTN="$OUTN $k(${OUTS[$k]})"; printf '%-28s %-4s %s\n' "$k" both "OUT ${OUTS[$k]} (OUTSIDE.tsv): not run, out of the denominator"; continue; fi
  TOTAL=$((TOTAL+1)); f="$BD/$k.$EXT"; ref="$BD/$k.ref"
  kb="$(declared_arena_kb_beside "$f")" || refuse "$k: its .heap sidecar is refused (the reader said why above)"
  st="$(declared_stack_kb_beside "$f")" || refuse "$k: its .stack sidecar is refused (the reader said why above)"
  cfg="shipped"; [ -n "$kb" ] && { cfg="SCRIP_HEAP_CAP_KB=$kb"; HEAPD=$((HEAPD+1)); }
  [ -n "$st" ] && { cfg="$([ "$cfg" = shipped ] || printf '%s,' "$cfg")SCRIP_STACK=${st}k"; HEAPD=$((HEAPD+1)); }
  if [ ! -s "$ref" ]; then
    for m in m3 m4; do printf 'benchmark\t%s\t%s\t%s\t%s\tFAIL\t0\tno-ref\t%s\n' "$SUITE_KEY" "$LANG_KEY" "$k" "$m" "$cfg" >>"$PROG_ROWS"; done
    printf '%-28s %-4s %s\n' "$k" both "FAIL no .ref -- a benchmark without a REF cannot be graded, and is counted, not skipped"; NAMED="$NAMED $k(no-ref)"; continue
  fi
  want="$(python3 -c 'import sys; print(len(open(sys.argv[1], encoding="utf-8", errors="surrogateescape").read()))' "$ref")"
  gen_ok=1
  for a in iter time; do { [ $a = iter ] && [ $DO_I = 0 ]; } || { [ $a = time ] && [ $DO_T = 0 ]; } && continue
    python3 "$GEN" "$f" --mode "$a" --n "$ITER_N" --bud-ms "$BUD_MS" -o "$T/$k.$a.$EXT" 2>"$T/$k.$a.gen" || gen_ok=0; done
  okboth=1
  for m in m3 m4; do
    _tm="$(progress_clock)"   # the mode's own wall for its row: its three angles, and in m4 their compile and link (CEO-1676 (c))
    r1=FAIL; r2=FAIL; r3=FAIL; why=""; [ $DO_P = 1 ] || r1=-; [ $DO_I = 1 ] || r2=-; [ $DO_T = 1 ] || r3=-
    if [ "$gen_ok" = 0 ]; then why="the wrapper generator REFUSED: $(head -c 160 "$T/$k.iter.gen" "$T/$k.time.gen" 2>/dev/null | tr '\n' ' ')"
    else
      if [ "$m" = m3 ]; then P=("$SCRIP" --run "$f"); I=("$SCRIP" --run "$T/$k.iter.$EXT"); TM=("$SCRIP" --run "$T/$k.time.$EXT")
      else
        if { [ $DO_P = 0 ] || build4 "$f" "$T/$k.p4"; } && { [ $DO_I = 0 ] || build4 "$T/$k.iter.$EXT" "$T/$k.i4"; } && { [ $DO_T = 0 ] || build4 "$T/$k.time.$EXT" "$T/$k.t4"; }; then P=("$T/$k.p4"); I=("$T/$k.i4"); TM=("$T/$k.t4")
        else why="m4 compile/link failed: $(cat "$T/$k.p4.cc" "$T/$k.i4.cc" "$T/$k.t4.cc" 2>/dev/null | head -c 160 | tr '\n' ' ')"; fi
      fi
      if [ -z "$why" ]; then
        if [ $DO_P = 1 ]; then run1 "$T/$k.$m.p" "$kb" "$WRAP" "${P[@]}"; rc=$?
          if [ "$rc" = 0 ] && cmp -s "$T/$k.$m.p.out" "$ref"; then r1=PASS; else why="process: rc=$rc$(cmp -s "$T/$k.$m.p.out" "$ref" || echo ', output differs from .ref')"; fi
          grep -h '^BENCH_RUSAGE' "$T/$k.$m.p.err" | sed "s/^/    scouting $k $m: /"; fi
        if [ $DO_I = 1 ]; then run1 "$T/$k.$m.i" "$kb" "${I[@]}"; rc=$?; w="$(bench_ok "$T/$k.$m.i.err" iter "$want")"
          if [ "$rc" = 0 ] && cmp -s "$T/$k.$m.i.out" "$ref" && [ -z "$w" ]; then r2=PASS; else why="$why; iter: rc=$rc$(cmp -s "$T/$k.$m.i.out" "$ref" || echo ', stdout differs from .ref')${w:+, $w}"; fi
          grep -h '^BENCH mode=' "$T/$k.$m.i.err" | sed "s/^/    scouting $k $m: /"; fi
        if [ $DO_T = 1 ]; then run1 "$T/$k.$m.t" "$kb" "${TM[@]}"; rc=$?; w="$(bench_ok "$T/$k.$m.t.err" time "$want")"
          if [ "$rc" = 0 ] && cmp -s "$T/$k.$m.t.out" "$ref" && [ -z "$w" ]; then r3=PASS; else why="$why; time: rc=$rc$(cmp -s "$T/$k.$m.t.out" "$ref" || echo ', stdout differs from .ref')${w:+, $w}"; fi
          grep -h '^BENCH mode=' "$T/$k.$m.t.err" | sed "s/^/    scouting $k $m: /"; fi
      fi
    fi
    if [ "$(printf '%s%s%s' "$r1" "$r2" "$r3" | tr -d '-')" = "$(printf 'PASS%.0s' $(seq $((DO_P+DO_I+DO_T))))" ]; then v=PASS; PASSN[$m]=$((PASSN[$m]+1)); note="ref-under-$(tr ',' '+' <<<"$ANGLES")"
    # a wrapper the generator refused is no grade of the program: REFUSE, could not measure, never FAIL (the coo 2026-10-22, COO-396: RakBench's four
    # 10-15 refusals read FAIL in the red lists the cto was sent)
    else v=FAIL; [ "$gen_ok" = 0 ] && v=REFUSE; okboth=0; note="$(echo "$why" | sed 's/^[; ]*//' | tr '\t' ' ')"; NAMED="$NAMED $k.$m$([ "$v" = REFUSE ] && echo "(refused)")"; fi
    SM="$(progress_secs_since "$_tm")"
    printf 'benchmark\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$SUITE_KEY" "$LANG_KEY" "$k" "$m" "$v" "$SM" "$note" "$cfg" >>"$PROG_ROWS"
    printf '%-28s %-4s %-7s %-7s %-7s %s\n' "$k" "$m" "$r1" "$r2" "$r3" "$v${why:+ -- $(echo "$why" | sed 's/^[; ]*//')}"
  done
  [ "$okboth" = 1 ] && BOTH=$((BOTH+1))
done
LINE="SUITE_BOARD family=$SUITE_KEY total=$TOTAL shipped=$((TOTAL+NOUT))$([ "$NOUT" -gt 0 ] && echo " excluded=$NOUT") all_pass=$BOTH all_n=$TOTAL m3_pass=${PASSN[m3]} m4_pass=${PASSN[m4]} angles=$ANGLES iter_n=$ITER_N bud_ms=$BUD_MS memory_declared=$HEAPD"
echo
echo "$LINE"
[ -n "$NAMED" ] && echo "  not passing:$NAMED"
[ -n "$OUTN" ] && echo "  not run, out of the denominator (OUTSIDE.tsv, Lon 2026-10-10):$OUTN"
echo "  tree: SCRIP=$(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null)$(git -C "$HERE/../../SCRIP" diff --quiet 2>/dev/null || echo -dirty) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)$(git -C "$S4E/corpus" diff --quiet 2>/dev/null || echo -dirty) RT_OPT=-O0"
if [ "$IS_BOARD" = 0 ]; then
  echo "  population $BD is OUTSIDE the corpus tree -- not a board (CEO-547): graded, and no progress row and no suite row written"
else
  progress_append_rows_tsv "$PROG_ROWS" || echo "⚠ PROGRESS DB NOT UPDATED -- the board above stands, its per-program rows do not (reason above)" >&2
  rr_selected && { rr_end "$SUITE_KEY"; [ "$BOTH" = "$TOTAL" ] && exit 0 || exit 1; }
  . "$HERE/lib_bench_write.sh" || refuse "lib_bench_write.sh unloadable -- the one rule for when a bench row publishes"
  read -r WRITE WRITE_WHY <<<"$(bench_row_writes "$(cd "$HERE/../.." && pwd)/corpus/benchmarks/raku" "$BD" "" "$NOWRITE")"
  echo "  row write: $([ "$WRITE" = 1 ] && echo yes || echo no) -- $WRITE_WHY"
  if [ "$WRITE" = 1 ]; then
    python3 "$HERE/util_score_row.py" write --lang "$LANG_KEY" --column bench-ref --measurer "${S4E_SEAT:-}" --text "$LINE" \
      ${S4E_CRITERION_CHANGED:+--criterion-changed "$S4E_CRITERION_CHANGED"} $([ "$NOUT" -gt 0 ] && echo "--excluded $NOUT") \
      || echo "⚠ SUITE ROW NOT WRITTEN -- util_score_row.py refused (reason above)"
  else
    echo "  suite row: not written ($WRITE_WHY; a whole-population pass publishes by default, the Raku lane's seat publishes: util_score_row.py write --lang raku --column bench-ref)"
  fi
fi
[ "$BOTH" = "$TOTAL" ] && exit 0 || exit 1
