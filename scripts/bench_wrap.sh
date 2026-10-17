#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_wrap.sh -- BUILD A TIMED BENCHMARK ON THE FLY FROM A REAL STANDALONE PROGRAM.
#
#   bash ../harness/scripts/bench_wrap.sh <prog.sno> [-o <out.sno>] [-H <harness.inc>]
#                              [--mode=time|iter] [--n=<iterations>] [--bud=<ms>]
#
# ⭐ WHY THIS EXISTS (Lon 2026-08-23 s265, in-chat, verbatim in substance: *"the system does NOT have
#   the stand alone program and has all that WRAPPER actually in the SOURCE CODE, and there is NO REF
#   files ... REVAMP the benchmark harness to have the *.sno file look like and BE the REAL program
#   application that can be run stand alone, and you can make temporary versions you build on the fly
#   with WHATEVER WRAPPERs you need"*).
#
#   BEFORE: every corpus/benchmarks/snobol4 program WAS the wrapper.  It set ZCHK/ZBUD/ZFLR, defined
#   ZBODY(ZKN), and ended in `-INCLUDE 'harness.inc'` -- no END of its own, no real output, not
#   runnable standalone, and its .ref pinned a harness artifact ("check: 1000") instead of the
#   program's answer.  Two carried no .ref at all.  The demo family was worse: those are REAL
#   applications (a Porter stemmer, a JSON deserializer) whose every OUTPUT had been DELETED and
#   replaced by a running sum, so a 163 KB oracle-gradeable answer became one integer.
#
#   AFTER: the .sno IS the application.  It has its own END, prints its own real output, runs under
#   `scrip p.sno`, `sbl -bf p.sno` and csnobol4 with no include path and no harness on disk, and its
#   .ref is that real output.  THIS script builds the timed version, into a temp file, when someone
#   wants a number.  The wrapper is now downstream of the program instead of inside it.
#
# THE CONTRACT -- one SNOBOL4 comment line, anywhere in the file, splitting it in two:
#
#     *BENCH kernel=<FN> check=<N> bud=<ms> flr=<ms> [batch=<K>]
#
#   ABOVE it   = the SETUP section: shared declarations, the pattern library, the kernel function.
#   BELOW it   = the MAIN section: the standalone application's own driver, and its END.
#   The line is a comment (`*` in column 1), so it is inert to every engine and the program stays
#   standalone.  It is the ONLY thing this script needs to know.
#
#   kernel=<FN>  a 1-arg program-defined function FN(N) that performs N repetitions of the workload
#                and RETURNS a deterministic census value.  It lives in the SETUP section, so both
#                arms have it, and the standalone MAIN uses it wherever that is the natural driver.
#   check=<N>    phase-1 iteration count -- fixes the deterministic check value.
#   bud=<ms>     phase-3 time budget.        flr=<ms>  phase-2 calibration floor.
#   batch=<K>    OPTIONAL -- pins the batch for a kernel that is not steady-state (string_concat),
#                where batch size is part of the workload and must not float.
#
# WHAT IT EMITS: SETUP verbatim, then the harness contract variables, then a one-line ZBODY shim
# that calls FN, then the body of harness.inc INLINED.  Inlined, not included: the generated file
# then has no include-path dependency at all, so it runs from any directory under either engine --
# which is what lets the temp file live in a mktemp dir beside nothing.  It also carries a `*` comment
# with the util_perf_context.sh CONTEXT line stamped at build time (load/cores/runnable/scrip+sbl
# procs) -- the same stamp goes to stderr as `stamp: ...`. Missing/failing util_perf_context.sh REFUSES
# the emission (rc=2) rather than silently shipping an unstamped twin.
#
# ⭐ THREE WAYS TO GET A NUMBER OUT OF ONE PROGRAM (Lon s265: *"we should have three options"*):
#     1. STANDALONE          -- do not call this script at all.  Run the .sno and time it from OUTSIDE:
#                               `/usr/bin/time -v ./scrip roman.sno`, `perf stat`, `valgrind --tool=callgrind`.
#                               The program prints its real answer, so the run is graded and timed at once.
#     2. --mode=time (default) -- fix the ms budget (--bud, default from the marker), COUNT THE ITERATIONS.
#     3. --mode=iter --n=N   -- run EXACTLY N iterations, no wall-clock deadline anywhere.  This is the arm
#                               to use under callgrind/cachegrind, where a deadline measures the
#                               INSTRUMENT's throughput instead of the kernel's
#                               (FINDING-2026-08-22-bench-harness-unmeasurable).
#   ⛔ --mode=iter BAKES `fixed_n` into the generated program instead of piping it on stdin.  That is what
#   makes mode 3 reachable for a DATA-DRIVEN benchmark at all: porter/json/claws5/calculator read their
#   corpus from stdin, so the old `fixed_n = INPUT` gate could never see a count for them -- they were
#   silently time-based-only and nobody had said so.
#
# ⛔ NO SILENT FALLBACK.  A program with no marker, a malformed marker, or a missing harness template
# is a NAMED FAILURE on stderr with rc=2.  The defect this replaces is exactly the invisible-skip
# class: test_bench_snobol4_timed.sh used to decide "is this a benchmark?" by grepping for the
# include, so a program that lost it vanished from the table rather than reddening it.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROG=""; OUT=""; HARNESS="${BENCH_HARNESS:-}"; MODE=time; NITER=""; BUDOV=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUT="$2"; shift 2 ;;
    -H) HARNESS="$2"; shift 2 ;;
    --mode=*) MODE="${1#--mode=}"; shift ;;
    --n=*)    NITER="${1#--n=}"; shift ;;
    --bud=*)  BUDOV="${1#--bud=}"; shift ;;
    -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)  [ -z "$PROG" ] || { echo "bench_wrap.sh: unexpected argument '$1'" >&2; exit 2; }; PROG="$1"; shift ;;
  esac
done
[ -n "$PROG" ] || { echo "usage: bench_wrap.sh <prog.sno> [-o out.sno] [-H harness.inc] [--mode=time|iter] [--n=N] [--bud=ms]" >&2; exit 2; }
case "$MODE" in
  time) [ -z "$NITER" ] || { echo "bench_wrap.sh: --n=$NITER is meaningless with --mode=time (the budget decides the count); use --mode=iter" >&2; exit 2; } ;;
  iter) [ -n "$NITER" ] || { echo "bench_wrap.sh: --mode=iter needs --n=<iterations>" >&2; exit 2; }
        case "$NITER" in ''|*[!0-9]*|0) echo "bench_wrap.sh: --n must be a positive integer, got '$NITER'" >&2; exit 2 ;; esac ;;
  *)    echo "bench_wrap.sh: unknown --mode='$MODE' (time|iter; standalone means do not call this script)" >&2; exit 2 ;;
esac
[ -f "$PROG" ] || { echo "bench_wrap.sh: no such program: $PROG" >&2; exit 2; }
PDIR="$(cd "$(dirname "$PROG")" && pwd)"; BASE="$(basename "${PROG%.sno}")"
# harness template: explicit -H, else beside the program, else one level up (the demo/ subfamily).
if [ -z "$HARNESS" ]; then
  if   [ -f "$PDIR/harness.inc" ];    then HARNESS="$PDIR/harness.inc"
  elif [ -f "$PDIR/../harness.inc" ]; then HARNESS="$PDIR/../harness.inc"; fi
fi
[ -n "$HARNESS" ] && [ -f "$HARNESS" ] || { echo "bench_wrap.sh: harness template not found for $PROG (looked beside it and one level up; override with -H)" >&2; exit 2; }
# ---------------------------------------------------------------- the marker: exactly one, parsed strictly
MARK_N=$(grep -n '^\*BENCH[[:space:]]' "$PROG" | cut -d: -f1)
[ -n "$MARK_N" ] || { echo "bench_wrap.sh: $PROG carries no '*BENCH kernel=... check=...' marker -- it is not a wrappable benchmark" >&2; exit 2; }
[ "$(wc -w <<<"$MARK_N")" -eq 1 ] || { echo "bench_wrap.sh: $PROG carries $(wc -w <<<"$MARK_N") *BENCH markers; exactly one is allowed" >&2; exit 2; }
MARK="$(sed -n "${MARK_N}p" "$PROG")"
attr() { sed -n "s/.*[[:space:]]$1=\([^[:space:]]*\).*/\1/p" <<<" $MARK "; }
KERNEL="$(attr kernel)"; CHECK="$(attr check)"; BUD="$(attr bud)"; FLR="$(attr flr)"; BATCH="$(attr batch)"
[ -n "$KERNEL" ] || { echo "bench_wrap.sh: $PROG marker has no kernel=<FN>: $MARK" >&2; exit 2; }
[ -n "$CHECK"  ] || { echo "bench_wrap.sh: $PROG marker has no check=<N>: $MARK"  >&2; exit 2; }
BUD="${BUD:-500}"; FLR="${FLR:-20}"
case "$CHECK$BUD$FLR${BATCH:-1}" in *[!0-9]*) echo "bench_wrap.sh: $PROG marker has a non-integer check/bud/flr/batch: $MARK" >&2; exit 2 ;; esac
grep -q "DEFINE('$KERNEL(" "$PROG" || { echo "bench_wrap.sh: $PROG names kernel '$KERNEL' but defines no DEFINE('$KERNEL(...)') -- the timed arm would call a null function and read as infinitely fast" >&2; exit 2; }
[ "$MARK_N" -gt 1 ] || { echo "bench_wrap.sh: $PROG has an empty SETUP section (marker on line 1)" >&2; exit 2; }
# ⛔ NO GOTO MAY CROSS THE MARKER.  The timed twin is built from the SETUP section alone, so a SETUP
# statement branching to a label defined only in MAIN would compile to a dangling transfer in the twin
# and nowhere else -- a defect visible only when timing.  END is exempt: both arms have one.
SETUP_LBL="$(sed -n "1,$((MARK_N-1))p" "$PROG" | sed -n 's/^\([A-Za-z][A-Za-z0-9_.]*\).*/\1/p' | sort -u)"
CROSS=""
for t in $(sed -n "1,$((MARK_N-1))p" "$PROG" | grep -oE ':[SF]?\([A-Za-z][A-Za-z0-9_.]*\)' | sed 's/^:[SF]\?(//; s/)$//' | sort -u); do
  case "$t" in END|RETURN|FRETURN|NRETURN) continue ;; esac
  grep -qx "$t" <<<"$SETUP_LBL" || CROSS="$CROSS $t"
done
[ -z "$CROSS" ] || { echo "bench_wrap.sh: $PROG has SETUP goto(s) crossing the *BENCH marker into MAIN:$CROSS -- move the label above the marker (the timed twin is built from SETUP alone)" >&2; exit 2; }
# ---------------------------------------------------------------- emit
# SYS-PERF ATTRIBUTION (bench-wrap-sysperf-stamp): a shared box running many concurrent sessions makes
# wall-clock untrustworthy without load context (RULES.md, hq_C). REFUSE rather than caveat -- an
# unstamped emission is exactly the silent-degradation shape this row exists to close. This stamps the
# BUILD, not the run: the actual measured wall-clock number is quoted later by whatever harness executes
# the twin (test_bench_snobol4_timed.sh and friends) -- that runtime WAIT-BOUND refusal is hq_C's C
# envelope (schedstat runqueue wait), coordinated separately so this row does not grow a second one.
PCTX="$HERE/util_perf_context.sh"
[ -x "$PCTX" ] || { echo "bench_wrap.sh: $PCTX missing or not executable -- refusing to emit an unstamped twin" >&2; exit 2; }
CTX="$("$PCTX" stamp)" || { echo "bench_wrap.sh: util_perf_context.sh stamp failed -- refusing to emit an unstamped twin" >&2; exit 2; }
: "${OUT:=$(mktemp --suffix=.sno "${TMPDIR:-/tmp}/bench_${BASE}_XXXXXX")}"
{
  echo "* GENERATED by ../harness/scripts/bench_wrap.sh from $BASE.sno -- DO NOT EDIT, DO NOT COMMIT."
  echo "* The program is the source of truth; this file is its timed twin and is rebuilt on every run."
  echo "* mode=$MODE${NITER:+ n=$NITER}"
  echo "* $CTX"
  sed -n "1,$((MARK_N-1))p" "$PROG"
  echo "        ZCHK = $CHECK"
  echo "        ZBUD = ${BUDOV:-$BUD}"
  echo "        ZFLR = $FLR"
  [ -n "$BATCH" ] && echo "        ZK = $BATCH"
  [ "$MODE" = iter ] && echo "        fixed_n = $NITER"
  echo "        DEFINE('ZBODY(ZKN)')                            :(ZBODY_END)"
  echo "ZBODY   ZBODY = $KERNEL(ZKN)                            :(RETURN)"
  echo "ZBODY_END"
  cat "$HARNESS"
} > "$OUT"
echo "stamp: $CTX" >&2
echo "$OUT"
