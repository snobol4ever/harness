#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${BENCH_PROLOG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/corpus/benchmarks/prolog/bench}" || exit 2
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# test_prolog_bench_suite.sh -- THE PROLOG BENCHMARKS DOUBLE AS TESTS: every kernel graded in both modes under three angles, the
# REF held on every run (ProBench, key prolog-bench-ref; row prolog-benchmarks-double-as-tests-ref-in-out-through-the-three-angle-
# harness-with-a-row-in-the-suite-grid, CEO-1221, to the coo's contract COO-164). Lon, verbatim: "The reason to force a benchmark to
# also be a test is to guarantee it is not vacuous." -- "The source of the benchmark is the apple-core of the test, the wrapper code
# can be added to do both the test and the measurements."
# THE THREE ANGLES, per kernel, per mode: (1) PROCESS -- the pristine kernel under tools/bench_rusage, stdout == <k>.ref; (2) ITER --
# bench_prolog_wrap.sh --mode=iter --n=N: stdout == N copies of <k>.ref (lib_prolog_bench.sh's loop_check, the proof the loop looped);
# (3) TIME -- bench_prolog_wrap.sh --mode=time --bud=MS: the answer once (stdout == <k>.ref), every repetition held == to it or the run
# throws bench__mismatch, and a BENCH line with iters >= 1 and mismatched=0. A kernel PASSES a mode when all three pass; the row is the
# AND per program over both modes. Mode 4 compiles each program and links it -no-pie against out/libscrip_rt.so.
# POPULATION: corpus/benchmarks/prolog/bench/*.pl, the pristine kernels. The upstream copies under src/ and the per-engine
# preludes are not in it yet -- the row's NEXT converts src/ into kernels with oracle-cut REFs, and a kernel with no REF is counted
# FAIL, never skipped. Memory: a <k>.heap / <k>.stack sidecar is honoured through lib_declared_arena.sh.
# A whole-population pass publishes the suite row by default (CEO-1302 (a), lib_bench_write.sh; --no-write opts out): util_score_row.py write --lang prolog --column bench-ref. Exit: 0 every kernel passes, 1 not, 2 refused.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
BD="${BENCH_PROLOG_DIR:-$S4E/corpus/benchmarks/prolog/bench}"
GATE_NAME=test_prolog_bench_suite
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
. "$HERE/lib_prolog_bench.sh" 2>/dev/null || refuse "lib_prolog_bench.sh unloadable -- loop_check is the iteration angle's proof"
GEN="$HERE/bench_prolog_wrap.sh"; [ -x "$GEN" ] || refuse "no wrapper generator at $GEN -- angles 2 and 3 have nothing to run"
WRAP="$HERE/../../SCRIP/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O0 -o "$WRAP" "$HERE/../../SCRIP/tools/bench_rusage.c" || refuse "tools/bench_rusage failed to build -- angle 1 has no wrapper"
case "$ITER_N" in ''|*[!0-9]*|0) refuse "BENCH_ITER_N must be a positive integer (got '$ITER_N')";; esac
case "$BUD_MS" in ''|*[!0-9]*|0) refuse "BENCH_BUD_MS must be a positive whole number of milliseconds (got '$BUD_MS')";; esac
IS_BOARD=0; one_runner_suite_is_a_board "$BD" && IS_BOARD=1
mapfile -t KERNELS < <(find "$BD" -maxdepth 1 -type f -name '*.pl' -printf '%f\n' | sed 's/\.pl$//' | LC_ALL=C sort)
# ⭐ THE ROUND ROBIN'S SEAM (ceo CEO-1806/1812): under S4E_CHUNK=entry:<kernel>[,...] (a request) only those kernels are graded, their rows appended,
# and no suite row is written (rr_end)
. "$HERE/lib_rr.sh" && rr_load "$BD" || exit 2
if rr_selected; then _ks=(); for k in "${KERNELS[@]}"; do rr_admits "$k" && _ks+=("$k"); done; KERNELS=(${_ks[@]+"${_ks[@]}"}); fi
[ "${#KERNELS[@]}" -gt 0 ] || refuse "no *.pl under $BD -- a population of zero is not a green board"
# ⭐ OUTSIDE.tsv NAMES A KERNEL OUT OF THE DENOMINATOR (hq_prolog 2026-10-10, corpus 0bc5934ce: queens_clpfd, Lon's CEO-579 "Do not count the
# FD as failures for us", the OUTSIDE_CLPFD class of CEO-1593): kernel<TAB>CLASS<TAB>evidence. The kernel is still graded and its progress
# rows written (it grades the day CLP(FD) is in the baseline), but it leaves total/all_n and is shown as excluded=, so shipped = total +
# excluded reads off the line and the row's Excl column; a malformed row, another class, or a name that is no kernel refuses rc 2.
declare -A OUTS; NOUT=0; OUTN=""
if [ -f "$BD/OUTSIDE.tsv" ]; then
  while IFS=$'\t' read -r _ok _ocls _oev || [ -n "$_ok" ]; do
    case "$_ok" in ''|'#'*) continue ;; esac
    [ "$_ocls" = OUTSIDE_CLPFD ] || refuse "OUTSIDE.tsv names $_ok with class '$_ocls' -- OUTSIDE_CLPFD is the one class (CEO-579, CEO-1593)"
    [ -n "${_oev// /}" ] || refuse "OUTSIDE.tsv names $_ok with no evidence -- an exclusion with no measurement is an opinion"
    [ -f "$BD/$_ok.pl" ] || refuse "OUTSIDE.tsv names $_ok, which is no kernel under $BD"
    OUTS[$_ok]="$_ocls"
  done < "$BD/OUTSIDE.tsv"
fi
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PROG_ROWS="$T/progress.tsv"; : >"$PROG_ROWS"
run1() {
  local o="$1" kb="$2"; shift 2
  ( cd "$T" && [ -n "$kb" ] && export SCRIP_HEAP_CAP_KB="$kb" && unset SCRIP_HEAP_MB SCRIP_HEAP_KB; [ -n "${st:-}" ] && export SCRIP_STACK="${st}k"
    "$TIMEOUT_RETRY" 300s "$@" </dev/null >"$o.out" 2>"$o.err" )
}
# build4 <src.pl> <bin> -- the mode-4 binary of one program; returns 0 when it links
build4() {
  ( cd "$T" && "$TIMEOUT_RETRY" 300s "$SCRIP" --compile "$1" -o "$2.s" </dev/null >"$2.cc" 2>&1 ) \
    && ( cd "$T" && cc -m64 -no-pie "$2.s" -o "$2" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >>"$2.cc" 2>&1 )
}
# bench_ok <err-file> <mode> -- the generated wrapper's BENCH line holds: its mode, its count, and for time no mismatch
bench_ok() {
  local b; b="$(grep -m1 '^BENCH kernel=' "$1")" || { echo "no BENCH line (UNMEASURED)"; return 1; }
  case "$b" in *" mode=$2 "*) ;; *) echo "BENCH line of the wrong mode: $b"; return 1;; esac
  if [ "$2" = iter ]; then case "$b" in *" n=$ITER_N "*) return 0;; *) echo "BENCH n is not the $ITER_N asked for: $b"; return 1;; esac; fi
  local it; it="$(sed -n 's/.* iters=\([0-9]*\) .*/\1/p' <<<"$b")"
  [ "${it:-0}" -ge 1 ] 2>/dev/null || { echo "iters=${it:-?}: no repetition ran"; return 1; }
  case "$b" in *" mismatched=0 "*) return 0;; *) echo "a repetition computed another value: $b"; return 1;; esac
}
printf '%-20s %-4s %-7s %-7s %-7s %s\n' kernel mode process iter time verdict
declare -A PASSN; PASSN[m3]=0; PASSN[m4]=0; BOTH=0; TOTAL=0; NAMED=""; HEAPD=0
# ⭐ EACH KERNEL'S REF NAMES ITS ORACLE (ceo CEO-1603 (3), the coo 2026-10-10, on the swap CEO-1598): a ref is gprolog's answer unless a
# <k>.oracle sidecar beside the kernel (one line, NAME<TAB>ORACLE<TAB>why) names another. MEASURED: gprolog 1.6.0 refuses
# witness_depth_nrev8 ("fatal error: redefining built-in predicate append/3"), where 1.4.5 ignored the redefinition and answered with
# its own append/3 -- so that ref was never the kernel's answer under gprolog; it is swipl 9.0.4's (swipl -q -t halt), one oracle per
# dialect. The count rides on the board line (oracles=) and every non-gprolog kernel is named with its reason. A name outside
# gprolog|swipl refuses: a declaration nothing can check is not a declaration.
declare -A ORC; ORC[gprolog]=0; ORC[swipl]=0; ORC_NAMED=""
for k in "${KERNELS[@]}"; do
  f="$BD/$k.pl"; ref="$BD/$k.ref"; ocls="${OUTS[$k]:-}"
  if [ -n "$ocls" ]; then NOUT=$((NOUT+1)); OUTN="$OUTN $k($ocls)"; else TOTAL=$((TOTAL+1)); fi
  kb="$(declared_arena_kb_beside "$f")" || refuse "$k: its .heap sidecar is refused (the reader said why above)"
  st="$(declared_stack_kb_beside "$f")" || refuse "$k: its .stack sidecar is refused (the reader said why above)"
  cfg="shipped"; [ -n "$kb" ] && { cfg="SCRIP_HEAP_CAP_KB=$kb"; HEAPD=$((HEAPD+1)); }
  orc=gprolog; orc_why=""
  if [ -f "$BD/$k.oracle" ]; then
    IFS=$'\t' read -r _on orc orc_why < "$BD/$k.oracle"
    [ "$_on" = "$k" ] || refuse "$k.oracle names '$_on', not $k"
    case "$orc" in gprolog|swipl) ;; *) refuse "$k.oracle names oracle '$orc' -- gprolog or swipl";; esac
    [ -n "$orc_why" ] || refuse "$k.oracle names $orc and no reason"
  fi
  ORC[$orc]=$((${ORC[$orc]}+1)); [ "$orc" = gprolog ] || ORC_NAMED="$ORC_NAMED $k($orc: $orc_why)"
  [ -n "$st" ] && { cfg="$([ "$cfg" = shipped ] || printf '%s,' "$cfg")SCRIP_STACK=${st}k"; HEAPD=$((HEAPD+1)); }
  if [ ! -s "$ref" ]; then
    for m in m3 m4; do printf 'benchmark\tprolog-bench-ref\tprolog\t%s\t%s\tFAIL\t0\tno-ref\t%s\n' "$k" "$m" "$cfg" >>"$PROG_ROWS"; done
    printf '%-20s %-4s %s\n' "$k" both "FAIL no .ref -- a benchmark without a REF cannot be graded, and is counted, not skipped"; [ -n "$ocls" ] || NAMED="$NAMED $k(no-ref)"; continue
  fi
  gen_ok=1
  bash "$GEN" "$f" --mode=iter --n="$ITER_N" --engine=scrip -o "$T/$k.iter.pl" >/dev/null 2>"$T/$k.iter.gen" || gen_ok=0
  bash "$GEN" "$f" --mode=time --bud="$BUD_MS" --engine=scrip -o "$T/$k.time.pl" >/dev/null 2>"$T/$k.time.gen" || gen_ok=0
  okboth=1
  for m in m3 m4; do
    _tm="$(progress_clock)"   # the mode's own wall for its row: its three angles, and in m4 their compile and link (CEO-1676 (c))
    r1=FAIL; r2=FAIL; r3=FAIL; why=""
    if [ "$gen_ok" = 0 ]; then why="the wrapper generator REFUSED: $(head -c 160 "$T/$k.iter.gen" "$T/$k.time.gen" 2>/dev/null | tr '\n' ' ')"
    else
      if [ "$m" = m3 ]; then P=("$SCRIP" --run "$f"); I=("$SCRIP" --run "$T/$k.iter.pl"); TM=("$SCRIP" --run "$T/$k.time.pl")
      else
        if build4 "$f" "$T/$k.p4" && build4 "$T/$k.iter.pl" "$T/$k.i4" && build4 "$T/$k.time.pl" "$T/$k.t4"; then P=("$T/$k.p4"); I=("$T/$k.i4"); TM=("$T/$k.t4")
        else why="m4 compile/link failed: $(cat "$T/$k.p4.cc" "$T/$k.i4.cc" "$T/$k.t4.cc" 2>/dev/null | head -c 160 | tr '\n' ' ')"; fi
      fi
      if [ -z "$why" ]; then
        run1 "$T/$k.$m.p" "$kb" "$WRAP" "${P[@]}"; rc=$?
        if [ "$rc" = 0 ] && cmp -s "$T/$k.$m.p.out" "$ref"; then r1=PASS; else why="process: rc=$rc$(cmp -s "$T/$k.$m.p.out" "$ref" || echo ', output differs from .ref')"; fi
        run1 "$T/$k.$m.i" "$kb" "${I[@]}"; rc=$?; w="$(bench_ok "$T/$k.$m.i.err" iter)"; lc="$(loop_check scrip "$T/$k.$m.i.out" "$ITER_N" "$ref")"
        if [ "$rc" = 0 ] && [ -z "$lc" ] && [ -z "$w" ]; then r2=PASS; else why="$why; iter: rc=$rc${lc:+, $lc}${w:+, $w}"; fi
        run1 "$T/$k.$m.t" "$kb" "${TM[@]}"; rc=$?; w="$(bench_ok "$T/$k.$m.t.err" time)"
        if [ "$rc" = 0 ] && cmp -s "$T/$k.$m.t.out" "$ref" && [ -z "$w" ]; then r3=PASS
        else why="$why; time: rc=$rc$(cmp -s "$T/$k.$m.t.out" "$ref" || echo ', stdout differs from .ref')${w:+, $w}$(grep -m1 -o 'bench__mismatch([^)]*)' "$T/$k.$m.t.err" | sed 's/^/, /')"; fi
        for x in i t; do grep -h '^BENCH kernel=' "$T/$k.$m.$x.err" | sed "s/^/    scouting $k $m: /"; done
      fi
    fi
    if [ "$r1$r2$r3" = PASSPASSPASS ]; then v=PASS; [ -n "$ocls" ] || PASSN[$m]=$((PASSN[$m]+1)); note="ref-under-three-angles"
    # a wrapper the generator refused is no grade of the program: REFUSE, could not measure, never FAIL (the coo 2026-10-22, COO-396)
    else v=FAIL; [ "$gen_ok" = 0 ] && v=REFUSE; okboth=0; note="$(echo "$why" | sed 's/^[; ]*//' | tr '\t' ' ')"; [ -n "$ocls" ] || NAMED="$NAMED $k.$m$([ "$v" = REFUSE ] && echo "(refused)")"; fi
    [ -n "$ocls" ] && note="$ocls (OUTSIDE.tsv, out of the denominator): $note"
    SM="$(progress_secs_since "$_tm")"
    printf 'benchmark\tprolog-bench-ref\tprolog\t%s\t%s\t%s\t%s\t%s\t%s\n' "$k" "$m" "$v" "$SM" "$note" "$cfg" >>"$PROG_ROWS"
    printf '%-20s %-4s %-7s %-7s %-7s %s\n' "$k" "$m" "$r1" "$r2" "$r3" "$v${why:+ -- $(echo "$why" | sed 's/^[; ]*//')}"
  done
  [ "$okboth" = 1 ] && [ -z "$ocls" ] && BOTH=$((BOTH+1))
done
LINE="SUITE_BOARD family=prolog-bench-ref total=$TOTAL shipped=$((TOTAL+NOUT))$([ "$NOUT" -gt 0 ] && echo " excluded=$NOUT") all_pass=$BOTH all_n=$TOTAL m3_pass=${PASSN[m3]} m4_pass=${PASSN[m4]} angles=process,iter,time iter_n=$ITER_N bud_ms=$BUD_MS memory_declared=$HEAPD oracles=gprolog:${ORC[gprolog]},swipl:${ORC[swipl]}"
echo
echo "$LINE"
[ -n "$NAMED" ] && echo "  not passing:$NAMED"
[ -n "$OUTN" ] && echo "  graded and out of the denominator (OUTSIDE.tsv):$OUTN"
[ -n "$ORC_NAMED" ] && echo "  refs not cut from gprolog:$ORC_NAMED"
echo "  tree: SCRIP=$(git -C "$HERE/../../SCRIP" rev-parse --short HEAD 2>/dev/null)$(git -C "$HERE/../../SCRIP" diff --quiet 2>/dev/null || echo -dirty) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)$(git -C "$S4E/corpus" diff --quiet 2>/dev/null || echo -dirty)"
if [ "$IS_BOARD" = 0 ]; then
  echo "  population $BD is OUTSIDE the corpus tree -- not a board (CEO-547): graded, and no progress row and no suite row written"
else
  progress_append_rows_tsv "$PROG_ROWS" || echo "⚠ PROGRESS DB NOT UPDATED -- the board above stands, its per-program rows do not (reason above)" >&2
  rr_selected && { rr_end prolog-bench-ref; exit 0; }
  . "$HERE/lib_bench_write.sh" || refuse "lib_bench_write.sh unloadable -- the one rule for when a bench row publishes"
  read -r WRITE WRITE_WHY <<<"$(bench_row_writes "$(cd "$HERE/../.." && pwd)/corpus/benchmarks/prolog/bench" "$BD" "" "$NOWRITE")"
  echo "  row write: $([ "$WRITE" = 1 ] && echo yes || echo no) -- $WRITE_WHY"
  if [ "$WRITE" = 1 ]; then
    python3 "$HERE/util_score_row.py" write --lang prolog --column bench-ref --measurer "${S4E_SEAT:-}" --text "$LINE" \
      ${S4E_CRITERION_CHANGED:+--criterion-changed "$S4E_CRITERION_CHANGED"} $([ "$NOUT" -gt 0 ] && echo "--excluded $NOUT") \
      || echo "⚠ SUITE ROW NOT WRITTEN -- util_score_row.py refused (reason above)"
  else
    echo "  suite row: not written ($WRITE_WHY; a whole-population pass publishes by default, the Prolog lane's seat publishes: util_score_row.py write --lang prolog --column bench-ref)"
  fi
fi
[ "$BOTH" = "$TOTAL" ] && exit 0 || exit 1
