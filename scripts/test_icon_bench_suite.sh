#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" || exit 2
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# test_icon_bench_suite.sh -- THE ICON BENCHMARK SUITE, GRADED AS A TEST UNDER ALL THREE ANGLES, IN BOTH MODES (IcnBench)
#
# LON 2026-09-23, in-chat to hq_icon, verbatim: "So each of our benchmarks do double as correctness tests with REF files. If this is
# not so, make it so. Add all the benchmarks suites for each language to the test suite grid." -- "All the benchmark programs are
# meant to be the real deal with input and output if necessary, REF, IN, OUT files. Then the harness is responsible of taking that
# text and wrapping it in the 3-angle technique. One process measures system performance metrics, and the programs loop and measure
# two ways, by interation and by time." Law: RULES.md FACT RULE THE KERNEL CONVENTION and its 2026-09-23 addendum (CEO-1221), and
# CEO-1222 (OUT is REF). The row contract is the coo's, one for all seven languages: key icon-bench-ref, nick IcnBench.
#
# THE POPULATION is every .icn under corpus/benchmarks/icon, recursively, with a `procedure main` -- printed as the denominator.
# THE SIDECARS, per kernel NAME, beside it: REF = NAME.ref (cut from Arizona icont/iconx 9.5.25a, util_cut_icon_kernel_refs.sh);
#   IN = NAME.in, else NAME.stdin, else NAME.dat (the name the icont bench kernels arrived with), else /dev/null; ARGV = NAME.argv
#   through ipl_argv_read, the ONE reader; MEMORY = NAME.heap and NAME.stack, one line NAME<TAB>KB each, read through
#   declared_switches_beside (the harness's own reader) and passed as -d<kb>k -s<kb>k on THAT kernel's command line (CEO-1353).
# THE THREE ANGLES, in m3 (scrip --run) and m4 (--compile, gcc -no-pie, run), every run from the kernel's own directory (a kernel
#   opens its argv files by relative name), STDOUT compared with the REF on EVERY run:
#   process  the PRISTINE kernel under tools/bench_rusage (elapsed, CPU, RSS): stdout must be the REF.
#   iter     the generated wrapper (util_icon_bench_wrap.py), BENCH_MODE=iter BENCH_N=n: stdout must be n copies of the REF.
#   time     the same wrapper, BENCH_MODE=time BENCH_BUDGET_MS=ms: stdout must be k copies, k read from its own BENCH line.
#   The wrapper writes its BENCH line to stderr; a wrapped run that prints none is UNMEASURED, never a pass.
# ⛔ THE LOOP SHAPE IS THE ORACLE'S, NEVER AN ENGINE'S OWN. iconx runs the wrapped kernel at n=2 first: a kernel that prints two REFs
#   loops IN the process and both modes must too; one whose static or `initial` state carries across calls prints something else
#   under iconx and is iterated ONE PROCESS PER ITERATION in every engine (PROC). Letting each engine fall back on its own would let a
#   SCRIP loop defect pass as a PROC kernel. Before it, the oracle's run of the PRISTINE kernel is the REF's own check: a REF it
#   does not reproduce is REF DRIFT, and a kernel whose wrapped form alone misses the REF (its output turns on what the wrapper
#   adds -- &allocated, &progname) is WRAPPER-SENSITIVE. Either is UNPROVEN in both modes and named, never graded.
# NO OUT FILE (CEO-1222): the REF is the one expected-output file; each run's stdout lives in a temp dir removed at exit, or in
#   --out-dir as <dir>/<kernel>.<mode>.<angle>.stdout for inspection only.
# THE VERDICT: a kernel PASSES when all six runs (two modes x three angles) print its REF. Every kernel appends ONE progress row per
#   mode (class benchmark, suite icon-bench-ref): PASS when all three angles print the REF, else HANG / CRASH / UNPROVEN / FAIL, the
#   worst that applies -- util_score_row.py's CEO-750 cross-check refuses to publish a row with no appends behind it.
# ⛔ THE TIMINGS ARE SCOUTING DATA, NEVER A GRID: timing grids wait for the quiet box (CEO-1219), and bench_triangulate_icon.sh is the
#   timing instrument. The defaults (n=2, 200 ms) prove the machinery and the refs, not a rate. RT_OPT is -O0.
#
# USAGE: bash ../harness/scripts/test_icon_bench_suite.sh [--out-dir DIR] [--n N] [--bud-ms MS] [--timeout S] [--no-write] [kernel ...]
#   --no-write  do not publish; without it a whole-population pass (no kernel named) publishes (CEO-1302 (a)) through util_score_row.py --column bench-ref (key icon-bench-ref, nick IcnBench); non-fatal by design.
# EXIT 0 every kernel PASS; 1 any kernel not PASS; 2 REFUSED (no binary, no oracle, no population, a tool that cannot be built).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="$ROOT/scrip"; RT="$ROOT/out"; BD="$S4E/corpus/benchmarks/icon"; GEN="$HERE/util_icon_bench_wrap.py"
OUTDIR=""; NITER=2; BUD=200; TMO=300; NOWRITE=0; WANT=""
refuse() { echo "⛔ ICON BENCH SUITE REFUSE(2): $*"; exit 2; }
# ⭐ PUBLISHING IS THE DEFAULT (ceo CEO-1302 (a), lib_bench_write.sh): a whole-population pass writes its row, a subset or --no-write never does; --write is still accepted and changes nothing
while [ $# -gt 0 ]; do case "$1" in
  --out-dir) OUTDIR="$2"; shift 2;; --n) NITER="$2"; shift 2;; --bud-ms) BUD="$2"; shift 2;; --timeout) TMO="$2"; shift 2;;
  --write) shift;; --no-write) NOWRITE=1; shift;; -*) refuse "unknown argument '$1' (usage in the header)";; *) WANT="$WANT $1"; shift;; esac; done
[ "$NITER" -ge 2 ] 2>/dev/null || refuse "--n must be at least 2: one iteration cannot tell a kernel that loops from one that does not"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "cannot load lib_oracle_flags.sh -- the ONE oracle-path authority"
. "$HERE/lib_icon_ipl_isolation.sh" 2>/dev/null || refuse "cannot load lib_icon_ipl_isolation.sh -- the ONE argv-sidecar reader"
. "$HERE/lib_declared_arena.sh" 2>/dev/null || refuse "cannot load lib_declared_arena.sh -- the ONE declared-arena reader"
ICONT="$(icont_bin)" || refuse "the Arizona icont oracle is missing (reached by absolute path, never command -v)"
[ -x "$SCRIP" ] || refuse "scrip is not built at $SCRIP -- run make"
[ -f "$RT/libscrip_rt.so" ] || refuse "no runtime at $RT/libscrip_rt.so"
[ -f "$GEN" ] || refuse "the wrapper generator $GEN is missing"
[ -d "$BD" ] || refuse "no benchmark tree at $BD"
PW="$HERE/util_progress_append.py"; [ -f "$PW" ] || refuse "the one progress-database writer $PW is missing (CEO-331)"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" >/dev/null || refuse "the binary is older than the tree -- run make (util_require_fresh.sh)"
W="$(mktemp -d "${TMPDIR:-/tmp}/icnbench.XXXXXX")" || refuse "cannot make a work dir"; trap 'rm -rf "$W"' EXIT
[ -n "$OUTDIR" ] || OUTDIR="$W/out"; mkdir -p "$OUTDIR" || refuse "cannot make $OUTDIR"
RUSAGE="$W/bench_rusage"; gcc -o "$RUSAGE" "$ROOT/tools/bench_rusage.c" 2>"$W/rusage.err" || refuse "tools/bench_rusage.c did not build: $(head -1 "$W/rusage.err")"
POP=()
while IFS= read -r f; do grep -q '^[[:space:]]*procedure[[:space:]]\+main' "$f" || continue
  n="$(basename "$f" .icn)"; [ -n "$WANT" ] && ! grep -qw -- "$n" <<<"$WANT" && continue; POP+=("$f")
done < <(find "$BD" -type f -name '*.icn' | LC_ALL=C sort)
# ⭐ THE ROUND ROBIN'S SEAM AND THE LIST MODE (the coo 2026-10-23, the ceo's seam census; as test_raku_bench_suite.sh, lib_rr.sh): under
# S4E_CHUNK=entry:<kernel>[,...] only those kernels are graded, their rows appended, no suite row written (rr_end); under S4E_LIST=1 the
# population is printed (RR_POP, the key its progress rows carry) and nothing graded -- util_score_row.py from-progress reads it (rr_list)
. "$HERE/lib_rr.sh" && rr_load "$BD" || exit 2
if [ "${S4E_LIST:-}" = 1 ]; then _lp=(); for f in "${POP[@]}"; do _lp+=("${f#"$BD"/}"); done; rr_list ${_lp[@]+"${_lp[@]}"}; fi
if rr_selected; then _ps=(); for f in "${POP[@]}"; do rr_admits "${f#"$BD"/}" && _ps+=("$f"); done; POP=(${_ps[@]+"${_ps[@]}"}); fi
[ "${#POP[@]}" -gt 0 ] || refuse "an empty population under $BD -- a suite that grades nothing is not a pass"
stdin_of() { local b="${1%.icn}" x; for x in in stdin dat; do [ -f "$b.$x" ] && { echo "$b.$x"; return; }; done; echo /dev/null; }
refx() { local i; : >"$2"; for ((i = 0; i < $3; i++)); do cat "$1" >>"$2"; done; }
# go <cmd...> -- one run from the kernel's directory under bench_rusage (timeout INSIDE it, so a timeout reports exit=124 instead of
# orphaning the child), the engine's environment prefix in ENVP; stdout in $W/o, stderr in $W/e; RC, ITERS and WORK read back.
go() { ( cd "$KD" && env "${ENVP[@]}" "$RUSAGE" timeout -k 5 "$TMO" "$@" <"$IN" >"$W/o" 2>"$W/e" ); RC=$?  # timeout-retry: exempt -- a timed run: the rusage prefix wraps this timeout, so the tool's own process would enter the measurement -- and a timeout is retried once at util_timeout_retry.sh --longer (Lon 2026-10-15, in-chat to the coo: "do a retry with longer timeouts")
  [ "$RC" = 124 ] && { ( cd "$KD" && env "${ENVP[@]}" "$RUSAGE" timeout "$("$HERE/util_timeout_retry.sh" --longer "$TMO")" "$@" <"$IN" >"$W/o" 2>"$W/e" ); RC=$?; }  # timeout-retry: exempt -- the longer retry of the timed run above
  ITERS="$(sed -n 's/^BENCH iters=\([0-9]*\) .*/\1/p' "$W/e" | tail -1)"; WORK="$(sed -n 's/^BENCH .*work_ms=\([0-9-]*\).*/\1/p' "$W/e" | tail -1)"; }
sev() { case "$1" in PASS) echo 0;; FAIL) echo 1;; UNPROVEN) echo 2;; CRASH) echo 3;; HANG) echo 4;; esac; }
worst() { if [ "$(sev "$2")" -gt "$(sev "$1")" ]; then echo "$2"; else echo "$1"; fi; }
kind() { if [ "$RC" = 124 ]; then echo HANG; elif [ "$RC" -ge 128 ]; then echo CRASH; else echo FAIL; fi; }
# record <program> <mode> <outcome> <secs> <note> -- ONE row through the ONE writer, declaring the configuration the program ran
# under: the GC axis read under the SAME environment prefix as its runs (its declared heap included), else `shipped`.
record() { local cfg; cfg=$(env "${HEAPENV[@]}" python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import util_progress_append as p; a = p.gc_axis_env(); print(",".join("%s=%s" % kv for kv in a.items()) if a else "shipped")' "$HERE")
  python3 "$PW" append --class benchmark --suite icon-bench-ref --lang icon --program "$1" --mode "$2" --outcome "$3" --secs "$4" --note "$5" --config "$cfg" >/dev/null 2>"$W/p.err" \
    || { PREFUSED=$((PREFUSED + 1)); NOTES="$NOTES\n    $1 $2: the progress row was REFUSED -- $(head -1 "$W/p.err")"; }; }
echo "=== ICON BENCHMARK SUITE: ${#POP[@]} kernels x 2 modes x 3 angles, graded against each REF (SCRIP $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY), corpus $(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)$(git -C "$S4E/corpus" diff --quiet 2>/dev/null || echo -DIRTY), RT_OPT=-O0, iter n=$NITER, time budget ${BUD} ms, oracle $ICONT) ==="
PASS=0; P3=0; P4=0; REFLESS=0; DRIFT=0; WSENS=0; LIN=0; LPROC=0; HEAPD=0; PREFUSED=0; NOTES=""; SCOUT=""
for f in "${POP[@]}"; do
  rel="${f#"$BD"/}"; NM="$(basename "$f" .icn)"; KD="$(dirname "$f")"; ref="${f%.icn}.ref"; IN="$(stdin_of "$f")"; K="$W/k"; rm -rf "$K"; mkdir -p "$K"
  HEAPENV=(-u SCRIP_HEAP_MB); kb="$(declared_switches_beside "$f")"; krc=$?; declare -a SWA=(); [ -n "$kb" ] && read -r -a SWA <<<"$kb"
  # the ORACLE's declared environment, NAME.oracle_env (ceo CEO-1353 clause 8 (g)(3)): iconx's own knobs (MSTKSIZE, BLKSIZE, ...) for a
  # kernel that needs more than iconx's default, on every oracle run below and on no SCRIP run (the coo 2026-10-03: until now iconx ran
  # every kernel at its default, so a kernel that declared its oracle's need read REF DRIFT here).
  oe="$(declared_oracle_env_beside "$f")" || krc=2; declare -a OENV=(); [ -n "$oe" ] && read -r -a OENV <<<"$oe"
  declare -a AV=(); arc=0; [ -f "${f%.icn}.argv" ] && { ipl_argv_read "$f" AV || arc=$?; }
  if [ ! -s "$ref" ]; then REFLESS=$((REFLESS + 1)); printf '  %-40s REFLESS -- no non-empty .ref, not a pass\n' "$rel"
    record "$rel" m3 UNGRADED 0 "no .ref"; record "$rel" m4 UNGRADED 0 "no .ref"; continue; fi
  if [ "$krc" != 0 ] || [ "$arc" != 0 ]; then why="a malformed ${NM}.heap, ${NM}.stack or ${NM}.oracle_env (the reader said why above)"; [ "$arc" != 0 ] && why="a malformed ${NM}.argv (the reader said why above)"
    printf '  %-40s UNPROVEN -- %s\n' "$rel" "$why"; record "$rel" m3 UNPROVEN 0 "$why"; record "$rel" m4 UNPROVEN 0 "$why"; continue; fi
  # ⭐ THE DECLARATION RIDES THE COMMAND LINE AS SWITCHES (ceo CEO-1353): after scrip in m3, leading the binary's arguments in m4 (a --
  # before the kernel's argv), never SCRIP_HEAP_KB -- gc_heap.c reads that as the collector's WINDOW, so every declared kernel ran at
  # window = cap. The oracle runs get none of these switches; they get NAME.oracle_env (OENV above).
  [ -n "$kb" ] && HEAPD=$((HEAPD + 1))
  python3 "$GEN" "$f" >"$K/$NM.icn" 2>"$K/gen.err" || { printf '  %-40s UNPROVEN -- the wrapper generator refused: %s\n' "$rel" "$(head -1 "$K/gen.err")"
    record "$rel" m3 UNPROVEN 0 "unwrappable"; record "$rel" m4 UNPROVEN 0 "unwrappable"; continue; }
  # ---- the oracle: the REF's own check (the PRISTINE kernel), then the loop shape both modes are held to (the WRAPPED one)
  ENVP=(${OENV[@]+"${OENV[@]}"}); SHAPE=""; why=""
  if ! ( cd "$K" && "$ICONT" -s -o op "$f" && "$ICONT" -s -o ox "$NM.icn" ) >"$K/icont.log" 2>&1; then why="REF DRIFT: icont refuses the kernel or its wrapper -- $(grep -v '^$' "$K/icont.log" | head -1 | cut -c1-100)"
  else go "$K/op" ${AV[@]+"${AV[@]}"}
    if [ "$RC" != 0 ] || ! cmp -s "$W/o" "$ref"; then why="REF DRIFT: the oracle's own run of the pristine kernel (stdout, from its directory) is not this REF (exit=$RC) -- $(diff "$W/o" "$ref" | head -2 | tr '\n' ' ' | cut -c1-100)"
    else ENVP=(${OENV[@]+"${OENV[@]}"} BENCH_MODE=iter BENCH_N=2); go "$K/ox" ${AV[@]+"${AV[@]}"}; refx "$ref" "$W/r2" 2
      if [ "$RC" = 0 ] && cmp -s "$W/o" "$W/r2"; then SHAPE=IN
      else ENVP=(${OENV[@]+"${OENV[@]}"} BENCH_MODE=iter BENCH_N=1); go "$K/ox" ${AV[@]+"${AV[@]}"}
        if [ "$RC" = 0 ] && cmp -s "$W/o" "$ref"; then SHAPE=PROC
        else why="WRAPPER-SENSITIVE: the oracle prints the REF for the pristine kernel but not for the wrapped one (exit=$RC) -- its output depends on what the wrapper adds (&allocated, &progname, ...) -- $(diff "$W/o" "$ref" | head -2 | tr '\n' ' ' | cut -c1-80)"; fi
      fi
    fi
  fi
  if [ -z "$SHAPE" ]; then case "$why" in WRAPPER*) WSENS=$((WSENS + 1));; *) DRIFT=$((DRIFT + 1));; esac; printf '  %-40s UNPROVEN -- %s\n' "$rel" "${why%% --*}"; NOTES="$NOTES\n    $rel: $why"
    record "$rel" m3 UNPROVEN 0 "${why%% --*}"; record "$rel" m4 UNPROVEN 0 "${why%% --*}"; continue; fi
  [ "$SHAPE" = IN ] && LIN=$((LIN + 1)) || LPROC=$((LPROC + 1))
  o3=PASS; o4=PASS; s3=0; s4=0; cells=""
  for mode in m3 m4; do
    PRI=(); WRP=(); o=PASS
    if [ "$mode" = m3 ]; then PRI=("$SCRIP" ${SWA[@]+"${SWA[@]}"} "$f"); WRP=("$SCRIP" ${SWA[@]+"${SWA[@]}"} "$K/$NM.icn"); [ "${#AV[@]}" -gt 0 ] && { PRI+=(-- "${AV[@]}"); WRP+=(-- "${AV[@]}"); }
    else
      mkdir -p "$K/p4" "$K/w4"
      if ( cd "$KD" && "$SCRIP" --compile --out="$K/p4/$NM.s" "$f" </dev/null && gcc -no-pie -o "$K/p4/$NM" "$K/p4/$NM.s" "$RT/libscrip_rt.so" -lm -lstdc++ -lpthread -Wl,-rpath,"$RT" ) >"$K/m4p.log" 2>&1 \
         && ( cd "$KD" && "$SCRIP" --compile --out="$K/w4/$NM.s" "$K/$NM.icn" </dev/null && gcc -no-pie -o "$K/w4/$NM" "$K/w4/$NM.s" "$RT/libscrip_rt.so" -lm -lstdc++ -lpthread -Wl,-rpath,"$RT" ) >"$K/m4w.log" 2>&1; then
        PRI=("$K/p4/$NM" ${SWA[@]+"${SWA[@]}"}); WRP=("$K/w4/$NM" ${SWA[@]+"${SWA[@]}"})
        [ "${#AV[@]}" -gt 0 ] && { [ "${#SWA[@]}" -gt 0 ] && { PRI+=(--); WRP+=(--); }; PRI+=("${AV[@]}"); WRP+=("${AV[@]}"); }
      else o4=FAIL; cells="$cells m4=BUILD"; NOTES="$NOTES\n    $rel m4: did not compile and link -- $(tail -1 "$K"/m4?.log | cut -c1-120)"; continue; fi
    fi
    for angle in process iter time; do
      v=PASS
      case "$angle" in
        process) ENVP=("${HEAPENV[@]}"); go "${PRI[@]}"; cp "$W/o" "$W/got"; cp "$ref" "$W/want"
                 ens=$(sed -n 's/.*elapsed_ns=\([0-9]*\).*/\1/p' "$W/e" | tail -1); sec=$(awk -v n="${ens:-0}" 'BEGIN{printf "%.3f", n/1e9}')
                 [ "$mode" = m3 ] && s3=$sec || s4=$sec
                 SCOUT="$SCOUT\n  $rel $mode process elapsed_ms=$(( ${ens:-0} / 1000000 )) $(grep -o 'maxrss_kb=[0-9]*' "$W/e" | tail -1)";;
        iter)    if [ "$SHAPE" = IN ]; then ENVP=("${HEAPENV[@]}" BENCH_MODE=iter "BENCH_N=$NITER"); go "${WRP[@]}"; cp "$W/o" "$W/got"; refx "$ref" "$W/want" "$NITER"
                   [ "${ITERS:-}" = "$NITER" ] || v=UNPROVEN
                 else : >"$W/got"; : >"$W/want"; ITERS=0; WORK=0
                   for ((i = 0; i < NITER; i++)); do ENVP=("${HEAPENV[@]}" BENCH_MODE=iter BENCH_N=1); go "${WRP[@]}"; cat "$W/o" >>"$W/got"; cat "$ref" >>"$W/want"
                     [ "$RC" = 0 ] || break; [ "$(sed -n 's/^BENCH iters=\([0-9]*\) .*/\1/p' "$W/e" | tail -1)" = 1 ] || v=UNPROVEN; done; fi
                 SCOUT="$SCOUT\n  $rel $mode iter $SHAPE n=$NITER work_ms=${WORK:-?}";;
        time)    if [ "$SHAPE" = IN ]; then ENVP=("${HEAPENV[@]}" BENCH_MODE=time "BENCH_BUDGET_MS=$BUD"); go "${WRP[@]}"; cp "$W/o" "$W/got"; k="${ITERS:-}"
                   # no BENCH line: k is unknown, so the output cannot be counted against the REF -- UNMEASURED, not "wrong answer"
                   if [ -z "$k" ] || [ "$k" -lt 1 ]; then v=UNPROVEN; k=0; cp "$W/o" "$W/want"; else refx "$ref" "$W/want" "$k"; fi
                 else : >"$W/got"; : >"$W/want"; k=0; spent=0
                   while [ "$k" -eq 0 ] || [ "$spent" -lt "$BUD" ]; do ENVP=("${HEAPENV[@]}" BENCH_MODE=iter BENCH_N=1); go "${WRP[@]}"; cat "$W/o" >>"$W/got"; cat "$ref" >>"$W/want"
                     [ "$RC" = 0 ] || break; w1="${WORK:-0}"; k=$((k + 1)); spent=$((spent + w1)); [ "$w1" -le 0 ] && [ "$k" -ge 50 ] && break; done; fi
                 SCOUT="$SCOUT\n  $rel $mode time $SHAPE budget_ms=$BUD k=$k";;
      esac
      mkdir -p "$(dirname "$OUTDIR/$rel")"; cp "$W/got" "$OUTDIR/${rel%.icn}.$mode.$angle.stdout"
      if [ "$RC" != 0 ]; then v="$(kind)"; NOTES="$NOTES\n    $rel $mode $angle: exit=$RC -- $(grep -v '^BENCH' "$W/e" | head -1 | cut -c1-120)"
      elif ! cmp -s "$W/got" "$W/want"; then v=FAIL; NOTES="$NOTES\n    $rel $mode $angle: stdout is not the REF -- $(diff "$W/got" "$W/want" | head -3 | tr '\n' ' ' | cut -c1-140)"
      elif [ "$v" = UNPROVEN ]; then NOTES="$NOTES\n    $rel $mode $angle: UNMEASURED -- the wrapper's BENCH line is missing or does not count the iterations asked for"; fi
      [ "$mode" = m3 ] && o3=$(worst "$o3" "$v") || o4=$(worst "$o4" "$v")
      cells="$cells $mode.$angle=$v"
    done
  done
  [ "$o3" = PASS ] && P3=$((P3 + 1)); [ "$o4" = PASS ] && P4=$((P4 + 1))
  hnote=""; [ -n "$kb" ] && hnote=" at declared $kb"
  record "$rel" m3 "$o3" "$s3" "process/iter/time vs REF, loop $SHAPE$hnote"; record "$rel" m4 "$o4" "$s4" "process/iter/time vs REF, loop $SHAPE$hnote"
  if [ "$o3" = PASS ] && [ "$o4" = PASS ]; then PASS=$((PASS + 1)); printf '  %-40s PASS  (6 of 6 runs print the REF, loop %s)%s\n' "$rel" "$SHAPE" "${hnote:+ --$hnote}"
  else printf '  %-40s FAIL %s  (loop %s)\n' "$rel" "$cells" "$SHAPE"; fi
done
N=${#POP[@]}
[ -n "$NOTES" ] && printf 'NOT PASSING, NAMED:%b\n' "$NOTES"
printf 'SCOUTING DATA -- one run each on a loaded box, NOT A GRID (timing waits for the quiet box, CEO-1219):%b\n' "$SCOUT"
LINE="SUITE_BOARD family=icon-bench-ref total=$N shipped=$N all_pass=$PASS all_n=$N m3_pass=$P3 m4_pass=$P4 angles=process,iter,time loop_in=$LIN loop_proc=$LPROC refless=$REFLESS ref_drift=$DRIFT wrapper_sensitive=$WSENS heap_declared=$HEAPD"
echo "$LINE"
rr_selected && { rr_end icon-bench-ref; [ "$PASS" = "$N" ] && exit 0 || exit 1; }
[ "$PREFUSED" = 0 ] || echo "⚠ $PREFUSED progress row(s) REFUSED (named above) -- the board stands, but it cannot be published until they are recorded"
. "$HERE/lib_bench_write.sh" || refuse "lib_bench_write.sh unloadable -- the one rule for when a bench row publishes"
read -r WRITE WRITE_WHY <<<"$(bench_row_writes "$(cd "$HERE/../.." && pwd)/corpus/benchmarks/icon" "$BD" "$WANT" "$NOWRITE")"
echo "  row write: $([ "$WRITE" = 1 ] && echo yes || echo no) -- $WRITE_WHY"
if [ "$WRITE" = 1 ]; then
  python3 "$HERE/util_score_row.py" write --lang icon --column bench-ref --measurer "${S4E_SEAT:-}" --text "$LINE" \
    || echo "⚠ SCORE.md NOT UPDATED -- util_score_row.py refused (the line above says why); the row stays as last published"
fi
[ "$PASS" = "$N" ] && exit 0
exit 1
