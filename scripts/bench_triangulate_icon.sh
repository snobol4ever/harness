#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_triangulate_icon.sh -- THE THREE-ANGLE HARNESS FOR THE ICON BENCHMARK KERNELS (corpus/benchmarks/icon).
#
# LON 2026-09-23 (CEO-1221): "all language benchmarks need to be run through the three-angle harness: (1) wrapper process,
# (2) iterations, and (3) time limit." -- "The reason to force a benchmark to also be a test is to guarantee it is not
# vacuous." -- "The source of the benchmark is the apple-core of the test, the wrapper code can be added to do both the test
# and the measurements." Law: RULES.md THE KERNEL CONVENTION (CEO-567) and THE TWO-NUMBER BENCHMARK BASIS;
# ARCH-BENCH-CAMPAIGN-README-TABLES.md THREE-ANGLE TRIANGULATION. The Icon DEMO harness (bench_triangulate_demos_icon.sh)
# iterates whole processes because a JCON demo has no inner entry point; a KERNEL does, so this one loops IN the process.
#
# PER KERNEL, PER ENGINE (Arizona iconx, SCRIP mode 3, SCRIP mode 4), all from ONE generated wrapper
# (../harness/scripts/util_icon_bench_wrap.py -- the kernel source is never edited):
#   LOOP TEST  two iterations must print exactly two copies of the .ref. A kernel whose statics or `initial` carry state
#              across calls (queens numbers its solutions from a static) prints something else; it is then graded ONE
#              iteration per PROCESS for both angles and the row says PROC. Neither shape is exempt from the ref check.
#   ANGLE 2    fixed iterations: N from SCALE.tsv beside the kernels (name<TAB>N), else $BENCH_N_DEFAULT.
#   ANGLE 1    fixed time: iterate until $BUDGET_MS of in-process work time is spent (at least once).
#   ANGLE 3    every process runs under tools/bench_rusage: CPU (user+sys), elapsed, exit -- independent of the kernel's clock.
#   stdout must equal k copies of the .ref on EVERY run of every angle; a mismatch is a FAIL of that row whatever its speed.
# SIDECARS, the same as test_icon_bench_suite.sh (the correctness row): stdin NAME.in, else NAME.stdin, else NAME.dat; argv
# NAME.argv; the SCRIP engines run at the heap and stack NAME.heap and NAME.stack declare (declared_switches_beside), iconx at its own default or in the environment NAME.oracle_env declares.
# THE NUMBERS: WORK = the wrapper's own work_ms (compile phase and startup outside it), per iteration in microseconds; angle 1
# and angle 2 AGREE when within TOL_PCT, else the row is NOT CITABLE -- reported, never a correctness failure. ⛔ Timing grids
# wait for the quiet box (CEO-1219): --quick (200 ms budget, N=2) proves the machinery and the refs under all three angles now.
# ⛔ RT_OPT is -O0; no -O2 arm exists.
#
# EXIT 0 every (kernel, engine) row passes its ref under all three angles; 1 any row does not; 2 REFUSED.
# USAGE: bash ../harness/scripts/bench_triangulate_icon.sh [--quick] [--out FILE.tsv] [kernel ...]
#        BUDGET_MS=2000 BENCH_N_DEFAULT=3 TOL_PCT=15 ENGINES="iconx m3 m4" RUN_TIMEOUT=600
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="$ROOT/out"
BD="${ICON_BENCH_DIR:-$S4E/corpus/benchmarks/icon}"
BUDGET_MS="${BUDGET_MS:-2000}"; NDEF="${BENCH_N_DEFAULT:-3}"; TOL="${TOL_PCT:-15}"; ENGINES="${ENGINES:-iconx m3 m4}"
RTO="${RUN_TIMEOUT:-600}"; OUT=""; WANT=""
while [ $# -gt 0 ]; do case "$1" in --quick) BUDGET_MS=200; NDEF=2;; --out) OUT="$2"; shift;; *) WANT="$WANT $1";; esac; shift; done
refuse() { echo "⛔ ICON BENCH TRIANGULATION REFUSED(2): $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "cannot load lib_oracle_flags.sh -- the ONE oracle-path authority."
. "$HERE/lib_icon_ipl_isolation.sh" 2>/dev/null || refuse "cannot load lib_icon_ipl_isolation.sh -- the ONE argv-sidecar reader."
. "$HERE/lib_declared_arena.sh" 2>/dev/null || refuse "cannot load lib_declared_arena.sh -- the ONE declared-arena reader."
ICONT="$(icont_bin)" || refuse "the Arizona icont oracle is missing (not a command -v verdict: the oracles are not on PATH)."
[ -x "$SCRIP" ] || refuse "scrip is not built at $SCRIP -- run make."
[ -d "$BD" ] || refuse "no Icon benchmark tree at $BD"
W="$(mktemp -d "${TMPDIR:-/tmp}/icnbench.XXXXXX")" || refuse "cannot make a work dir"; trap 'rm -rf "$W"' EXIT
# built fresh into the work dir, plain gcc: never an -O2 build, and never a binary written into the tree
WRAP="$W/bench_rusage"; gcc -o "$WRAP" "$ROOT/tools/bench_rusage.c" 2>"$W/rusage.err" || refuse "tools/bench_rusage.c did not build: $(head -1 "$W/rusage.err")"
POP=()
while IFS= read -r f; do grep -q '^[[:space:]]*procedure[[:space:]]\+main' "$f" || continue
  n="$(basename "$f" .icn)"; [ -n "$WANT" ] && ! grep -qw -- "$n" <<<"$WANT" && continue; POP+=("$f")
done < <(find "$BD" -name '*.icn' ! -path '*/rate/*' | LC_ALL=C sort)
[ "${#POP[@]}" -gt 0 ] || refuse "no kernel matched under $BD -- a harness that measured nothing is not a pass."
scale_of() { local s; s="$(awk -F'\t' -v n="$1" '!/^#/ && $1==n {print $2; exit}' "$BD/SCALE.tsv" 2>/dev/null)"; echo "${s:-$NDEF}"; }
refx() { local i; : > "$2"; for ((i=0; i<$3; i++)); do cat "$1" >> "$2"; done; }
# run MODE COUNT_OR_BUDGET TAG -> sets R_ITERS R_WORK R_CPU R_ELAPSED R_EXIT, stdout in $W/$TAG.out
run() {
  local e
  ( cd "$KD" && env "${HEAPENV[@]}" BENCH_MODE="$1" BENCH_N="$2" BENCH_BUDGET_MS="$2" "$WRAP" timeout -k 5 "$RTO" "${CMD[@]}" <"$IN" >"$W/$3.out" 2>"$W/$3.err" )
  e="$(grep -m1 '^BENCH_RUSAGE:' "$W/$3.err")"
  fld() { local v; v="$(sed -n "s/.*[ :]$1=\([0-9]*\).*/\1/p" <<<"$e")"; echo "${v:-0}"; }
  R_EXIT="$(sed -n 's/.* exit=\([0-9-]*\).*/\1/p' <<<"$e")"; R_EXIT="${R_EXIT:-124}"
  R_CPU=$(( ( $(fld user_us) + $(fld sys_us) ) / 1000 )); R_ELAPSED=$(( $(fld elapsed_ns) / 1000000 ))
  R_ITERS="$(sed -n 's/^BENCH iters=\([0-9]*\) .*/\1/p' "$W/$3.err" | tail -1)"; R_WORK="$(sed -n 's/^BENCH .*work_ms=\([0-9-]*\).*/\1/p' "$W/$3.err" | tail -1)"
}
us_per() { [ "${2:-0}" -gt 0 ] 2>/dev/null && awk -v w="$1" -v k="$2" 'BEGIN{printf "%.1f", w*1000.0/k}' || echo "-"; }
BAD=0; ROWS=0
printf '%-30s %-6s %-5s %-24s %-24s %-11s %s\n' KERNEL ENGINE LOOP "A2 fixed-iter us/it(N)" "A1 fixed-time us/it(k)" "A1~A2" "VERDICT"
printf '%s\n' "----------------------------------------------------------------------------------------------------------------------------------"
[ -n "$OUT" ] && printf 'kernel\tengine\tloop\ta2_n\ta2_work_ms\ta2_cpu_ms\ta2_elapsed_ms\ta1_k\ta1_work_ms\ta1_cpu_ms\ta1_elapsed_ms\tagree\tverdict\n' > "$OUT"
for K in "${POP[@]}"; do
  KD="$(dirname "$K")"; NM="$(basename "$K" .icn)"; B="${K%.icn}"; REF="$B.ref"
  IN=/dev/null; for X in in stdin dat; do [ -f "$B.$X" ] && { IN="$B.$X"; break; }; done   # the suite's order (test_icon_bench_suite.sh)
  # ⭐ THE DECLARATION RIDES THE COMMAND LINE AS SWITCHES (ceo CEO-1353): -d<kb>k -s<kb>k from NAME.heap and NAME.stack after scrip in m3
  # and leading the binary's arguments in m4 (a -- before the kernel's argv), never SCRIP_HEAP_KB, the collector's WINDOW; iconx gets none of them, only NAME.oracle_env.
  SW="$(declared_switches_beside "$K")" || { echo "⛔ $NM: a malformed $NM.heap or $NM.stack (the reader said why above)"; BAD=1; continue; }
  declare -a SWA=(); [ -n "$SW" ] && read -r -a SWA <<<"$SW"
  # iconx runs in the environment NAME.oracle_env declares (ceo CEO-1353 clause 8 (g)(3)) and the SCRIP engines never see it.
  OE="$(declared_oracle_env_beside "$K")" || { echo "⛔ $NM: a malformed $NM.oracle_env (the reader said why above)"; BAD=1; continue; }
  declare -a OENV=(); [ -n "$OE" ] && read -r -a OENV <<<"$OE"
  declare -a AV=(); if [ -f "$B.argv" ] && ! ipl_argv_read "$K" AV; then echo "⛔ $NM: malformed $NM.argv"; BAD=1; continue; fi
  mkdir -p "$W/$NM"; python3 "$HERE/util_icon_bench_wrap.py" "$K" > "$W/$NM/$NM.icn" || { echo "⛔ $NM: the wrapper generator refused"; BAD=1; continue; }
  N="$(scale_of "$NM")"
  for EN in $ENGINES; do
    ROWS=$((ROWS+1)); V=PASS; CMD=()
    HEAPENV=(${OENV[@]+"${OENV[@]}"}); [ "$EN" != iconx ] && HEAPENV=(-u SCRIP_HEAP_MB)   # the oracle's declared env for iconx; SCRIP engines unset the window knob
    if [ ! -s "$REF" ]; then printf '%-30s %-6s %s\n' "$NM" "$EN" "FAIL -- no .ref: a kernel with no expected output is vacuous"; BAD=1; continue; fi
    case "$EN" in
      iconx) ( cd "$W/$NM" && "$ICONT" -s -o w.x "$NM.icn" ) >"$W/$NM/icont.log" 2>&1 && CMD=("$W/$NM/w.x" ${AV[@]+"${AV[@]}"});;
      m3)    CMD=("$SCRIP" ${SWA[@]+"${SWA[@]}"} "$W/$NM/$NM.icn"); [ "${#AV[@]}" -gt 0 ] && CMD+=(-- "${AV[@]}");;
      m4)    ( cd "$W/$NM" && "$SCRIP" --compile -o w.s "$NM.icn" </dev/null && gcc -no-pie -o w4 w.s "$RT/libscrip_rt.so" -lm -lstdc++ -lpthread -Wl,-rpath,"$RT" ) >"$W/$NM/m4.log" 2>&1 \
               && { CMD=("$W/$NM/w4" ${SWA[@]+"${SWA[@]}"}); [ "${#AV[@]}" -gt 0 ] && { [ "${#SWA[@]}" -gt 0 ] && CMD+=(--); CMD+=("${AV[@]}"); }; };;
      *) refuse "unknown engine $EN";;
    esac
    [ "${#CMD[@]}" -gt 0 ] || { printf '%-30s %-6s %s\n' "$NM" "$EN" "FAIL -- the wrapped kernel did not build ($(tail -1 "$W/$NM/"*.log 2>/dev/null | cut -c1-80))"; BAD=1; continue; }
    T="$NM.$EN"
    run iter 2 "$T.loop"; refx "$REF" "$W/$T.ref2" 2
    if [ "$R_EXIT" = 0 ] && cmp -s "$W/$T.loop.out" "$W/$T.ref2"; then LOOP=IN
    else run iter 1 "$T.one"
      if [ "$R_EXIT" = 0 ] && cmp -s "$W/$T.one.out" "$REF"; then LOOP=PROC
      else printf '%-30s %-6s %s\n' "$NM" "$EN" "FAIL -- one wrapped run exit=$R_EXIT does not print its .ref"; BAD=1; [ -n "$OUT" ] && printf '%s\t%s\t-\t\t\t\t\t\t\t\t\t\tFAIL\n' "$NM" "$EN" >> "$OUT"; continue; fi
    fi
    if [ "$LOOP" = IN ]; then
      run iter "$N" "$T.a2"; refx "$REF" "$W/$T.refN" "$N"
      { [ "$R_EXIT" = 0 ] && [ "${R_ITERS:-0}" = "$N" ] && cmp -s "$W/$T.a2.out" "$W/$T.refN"; } || V="FAIL(angle 2: exit=$R_EXIT iters=${R_ITERS:-?} of $N, output is not $N refs)"
      A2N=$N; A2W=${R_WORK:-0}; A2C=$R_CPU; A2E=$R_ELAPSED
      run time "$BUDGET_MS" "$T.a1"; K1=${R_ITERS:-0}; refx "$REF" "$W/$T.refK" "$K1"
      { [ "$R_EXIT" = 0 ] && [ "$K1" -ge 1 ] && cmp -s "$W/$T.a1.out" "$W/$T.refK"; } || V="FAIL(angle 1: exit=$R_EXIT iters=$K1, output is not $K1 refs)"
      A1W=${R_WORK:-0}; A1C=$R_CPU; A1E=$R_ELAPSED
    else
      A2N=0; A2W=0; A2C=0; A2E=0
      for ((i=0; i<N; i++)); do run iter 1 "$T.p2"; { [ "$R_EXIT" = 0 ] && cmp -s "$W/$T.p2.out" "$REF"; } || V="FAIL(angle 2 process $i)"; A2N=$((A2N+1)); A2W=$((A2W+${R_WORK:-0})); A2C=$((A2C+R_CPU)); A2E=$((A2E+R_ELAPSED)); done
      K1=0; A1W=0; A1C=0; A1E=0
      while [ "$K1" -eq 0 ] || [ "$A1W" -lt "$BUDGET_MS" ]; do run iter 1 "$T.p1"; { [ "$R_EXIT" = 0 ] && cmp -s "$W/$T.p1.out" "$REF"; } || { V="FAIL(angle 1 process $K1)"; break; }; K1=$((K1+1)); A1W=$((A1W+${R_WORK:-0})); A1C=$((A1C+R_CPU)); A1E=$((A1E+R_ELAPSED)); [ "${R_WORK:-0}" -le 0 ] && [ "$K1" -ge 50 ] && break; done
    fi
    U2="$(us_per "$A2W" "$A2N")"; U1="$(us_per "$A1W" "$K1")"
    AG="$(awk -v a="$U1" -v b="$U2" -v t="$TOL" 'BEGIN{ if (a=="-"||b=="-"||a+0<=0||b+0<=0) {print "n/a"; exit} d=(a>b?a-b:b-a)/(a<b?a:b)*100; print (d<=t?"AGREE":"DISAGREE") sprintf("(%.0f%%)",d)}')"
    [ "$V" = PASS ] || BAD=1
    printf '%-30s %-6s %-5s %-24s %-24s %-11s %s\n' "$NM" "$EN" "$LOOP" "$U2 ($A2N)" "$U1 ($K1)" "$AG" "$V"
    [ -n "$OUT" ] && printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$NM" "$EN" "$LOOP" "$A2N" "$A2W" "$A2C" "$A2E" "$K1" "$A1W" "$A1C" "$A1E" "$AG" "$V" >> "$OUT"
  done
done
printf '%s\n' "----------------------------------------------------------------------------------------------------------------------------------"
echo "ICON_BENCH_TRIANGULATION kernels=${#POP[@]} rows=$ROWS budget_ms=$BUDGET_MS n_default=$NDEF tol_pct=$TOL engines=\"$ENGINES\" RT_OPT=-O0 load=\"$(cut -d' ' -f1-3 /proc/loadavg)\""
echo "  WORK basis: the wrapper's in-process work_ms per iteration (startup and compile outside it); angle 3 CPU/elapsed per row in --out."
[ "$BAD" = 0 ] && { echo "✅ ICON BENCH TRIANGULATION PASS(0): every kernel printed its .ref on every run of all three angles, in every engine."; exit 0; }
echo "⛔ ICON BENCH TRIANGULATION FAIL(1): at least one row did not reproduce its .ref (rows above)."; exit 1
