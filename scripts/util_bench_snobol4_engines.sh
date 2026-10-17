#!/usr/bin/env bash
# util_bench_snobol4_engines.sh — run the 16-benchmark SNOBOL4 suite under ANY external engine,
# verifying output against .ref (ms: lines ignored) and normalizing self-reported timing to ms.
#
# Usage: util_bench_snobol4_engines.sh <label> <timeout_s> <divisor_to_ms> <cmd...>
#   <cmd...> is invoked as: cmd <bench.sno>  (stdin=/dev/null)
#
# Known engines + divisors (TIME() units differ per engine — measured 2026-07-10, s13):
#   official spitbol/x64:      1000000   .../official/spitbol-x64/sbl -b        (TIME() diffs = ns)
#   fork snobol4ever/x64:      1         /home/claude/x64/bin/sbl -bf           (patched: CPU-time ms; -bf not -b, see RULES.md oracle note)
#   official/fork csnobol4:    1         .../official/csnobol4/snobol4 -f       (ms)
# SCRIP itself: use test_bench_snobol4_modes.sh (mode-4 compile+run vs the same .ref set).
# Build the official engines first: ../harness/scripts/build_official_oracles.sh
#
# EXTERNAL CLOCK (row bench-external-cpu-and-elapsed-clock, Lon s200 directive): "self(ms)" above is
# STILL each engine timing ITSELF, and the two engines' TIME() are not even the same kind of clock
# (SPITBOL's is CPU-time-patched, SCRIP's is wall-clock — see tools/bench_rusage.c). Every row now
# ALSO carries elapsed(ms)/cpu(ms)/rss(kb)/nivcsw measured from OUTSIDE both engines: forked through
# tools/bench_rusage (built on demand below), reading wait4()'s rusage — the SAME instrument for
# every engine, blind to which one it is timing. nivcsw over $BENCH_NIVCSW_THRESHOLD (default 20 —
# an uncalibrated first-pass guess, not a measured statistic; override via env) marks a row LOAD in
# the flag column rather than silently averaging a scheduler-contaminated run in. TIME()'s self(ms)
# stays for continuity but is never again the cross-engine authority.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
B="${BENCH_DIR:-$S4E/corpus/benchmarks/snobol4}"
[ $# -ge 4 ] || { sed -n '2,12p' "$0"; exit 2; }
L="$1"; T="$2"; DIV="$3"; shift 3
WRAP="$S4E/SCRIP/tools/bench_rusage"
[ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$S4E/SCRIP/tools/bench_rusage.c" || { echo "FAIL build $WRAP" >&2; exit 1; }
NIVCSW_FLAG="${BENCH_NIVCSW_THRESHOLD:-20}"
printf "%-22s %-7s %11s %9s %10s %9s %7s %5s\n" "BENCH($L)" STATUS "elapsed(ms)" "cpu(ms)" "self(ms)" "rss(kb)" "nivcsw" "flag"
ok=0; fail=0; crash=0; loaded=0
for sno in "$B"/*.sno; do
  s=$(basename "${sno%.sno}"); ref="${sno%.sno}.ref"
  errfile="/tmp/_be.$$.err"
  out=$("$WRAP" timeout -k 5 "$T" "$@" "$sno" </dev/null 2>"$errfile"); rc=$?
  rusage_line=$(grep '^BENCH_RUSAGE:' "$errfile" | tail -1); rm -f "$errfile"
  elapsed_ms="-"; cpu_ms="-"; maxrss_kb="-"; nivcsw="-"
  if [ -n "$rusage_line" ]; then
    elapsed_ns=$(echo "$rusage_line" | grep -oE 'elapsed_ns=[0-9]+' | cut -d= -f2)
    user_us=$(echo "$rusage_line" | grep -oE 'user_us=[0-9]+' | cut -d= -f2)
    sys_us=$(echo "$rusage_line" | grep -oE 'sys_us=[0-9]+' | cut -d= -f2)
    rss_raw=$(echo "$rusage_line" | grep -oE 'maxrss_kb=[0-9]+' | cut -d= -f2); [ -n "$rss_raw" ] && maxrss_kb="$rss_raw"
    niv_raw=$(echo "$rusage_line" | grep -oE 'nivcsw=[0-9]+' | cut -d= -f2); [ -n "$niv_raw" ] && nivcsw="$niv_raw"
    [ -n "$elapsed_ns" ] && elapsed_ms=$(awk "BEGIN{printf \"%.1f\", $elapsed_ns/1000000}")
    [ -n "$user_us" ] && [ -n "$sys_us" ] && cpu_ms=$(awk "BEGIN{printf \"%.1f\", ($user_us+$sys_us)/1000}")
  fi
  raw=$(echo "$out" | grep -i 'ms:' | head -1 | sed -E 's/.*[Mm][Ss]:[[:space:]]*//' | awk '{print $1}')
  ms="-"; [ -n "$raw" ] && ms=$(awk "BEGIN{printf \"%.1f\", $raw/$DIV}" 2>/dev/null)
  flag="-"
  if [ "$nivcsw" != "-" ] && [ "$nivcsw" -gt "$NIVCSW_FLAG" ] 2>/dev/null; then flag="LOAD"; loaded=$((loaded+1)); fi
  if [ $rc -ne 0 ]; then st=CRASH; crash=$((crash+1)); ms="rc=$rc"
  elif [ -f "$ref" ] && ! diff -q <(echo "$out" | grep -viE 'ms:|iters:') <(grep -viE 'ms:|iters:' "$ref") >/dev/null 2>&1; then st=FAIL; fail=$((fail+1))
  else st=OK; ok=$((ok+1)); fi
  printf "%-22s %-7s %11s %9s %10s %9s %7s %5s\n" "$s" "$st" "$elapsed_ms" "$cpu_ms" "$ms" "$maxrss_kb" "$nivcsw" "$flag"
done
echo "RESULT($L): OK=$ok FAIL=$fail CRASH=$crash LOAD-FLAGGED=$loaded"
[ "$crash" -eq 0 ] && [ "$fail" -eq 0 ]
