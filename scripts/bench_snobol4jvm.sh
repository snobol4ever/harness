#!/bin/bash
# bench_snobol4jvm.sh -- THE SNOBOL4 BENCHMARKS UNDER snobol4jvm, graded as tests and timed against official SPITBOL
# (Lon 2026-10-17, in-chat to hq_jvm, verbatim: "I suspect getting the test harness and benchmarks to run is the first order of business."
# · "The suite banner should represent the snobol4jvm program, not SCRIP."; GOAL-HQ-JVM: "benchmark numbers against official SPITBOL
# (/home/resources/spitbol-bench-oracle/sbl), quoted as the bare multiple x (reference time over this port's time), each with its load
# stamped and the JVM's warm-up stated").
# POPULATION: every *.sno directly under corpus/benchmarks/snobol4, by extension (the SnoBench population). Each kernel's .ref is
# the standalone program's real output, cut from sbl -bf.
# THE TEST: the pristine kernel run once as a process under run_snobol4jvm.sh must print exactly its .ref with rc 0. The pass count is
# printed on the SNOBOL4JVM_BENCH line; this runner writes no score row (SnoBench@jvm enters the one SUITES.tsv through its writer, CEO-1822).
# THE TIMES, all wall clock from /usr/bin/time outside the program, so neither engine's TIME() units enter a number:
#   cold  -- the pristine kernel as one process: for snobol4jvm this includes the JVM start and the JIT's warm-up.
#   warm  -- per repetition of the kernel's work: bench_wrap_snobol4.py --mode iter generates the wrapper with --n 1 and --n K, and
#            warm = (T(K) - T(1)) / (K - 1), so the start, the test half and the first repetition cancel out; the JVM has run the
#            work at least once before the repetitions that count. EACH ENGINE finds its own K: it starts at 10 and grows tenfold
#            until that engine spends at least 1 s on the K - 1 repetitions (or K reaches 10^6). A run must print the .ref AND exit 0:
#            the wrapper prints the ref before its quiet repetitions, so a run killed by the 300 s cap still prints it, and only the
#            exit code tells the two apart (measured: ten kernels read 300 s / K before this check). A kernel the generator refuses,
#            or whose wrapper does not print the .ref or exit 0 at any K, reads warm=n/a.
#   x     -- the bare multiple, reference time over snobol4jvm's time, on each angle: x > 1 means snobol4jvm is faster. A reference
#            time under 0.05 s is below the stopwatch's resolution, and its x reads n/a rather than a ratio of noise.
# The reference is /home/resources/spitbol-bench-oracle/sbl -bf, the official upstream, never the x64 fork. The table is printed on stdout
# as TSV lines prefixed BENCH_TSV, with the load stamped at its start and end; the caller keeps it where it keeps its evidence.
# rc 0 = every kernel PASS · 1 = a kernel not PASS · 2 = refused.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
B="$ROOT/corpus/benchmarks/snobol4"; SBL=/home/resources/spitbol-bench-oracle/sbl; RUN="$HERE/run_snobol4jvm.sh"
[ $# -eq 0 ] || { echo "⛔ REFUSE(rc=2): bench_snobol4jvm.sh takes no arguments"; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSE(rc=2): no benchmark tree at $B"; exit 2; }
[ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2): no official SPITBOL at $SBL"; exit 2; }
J="$(bash "$RUN" --binaries --lang snobol4)" || exit 2; SJ="$(git -C "$(dirname "$J")" rev-parse --show-toplevel)"
tree="$(git -C "$SJ" rev-parse --short HEAD)$( [ -n "$(git -C "$SJ" status --porcelain --untracked-files=no)" ] && echo +dirty)"
day="$(TZ=America/Chicago date +%F)"; load0="$(cut -d' ' -f1-3 /proc/loadavg)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
TSV="$W/table.tsv"
printf '# snobol4jvm %s vs %s -bf, load at start %s on %s cores. Seconds are wall clock; x = sbl time / snobol4jvm time.\n' "$tree" "$SBL" "$load0" "$(nproc)" > "$TSV"
printf 'kernel\tverdict\tjvm_cold_s\tsbl_cold_s\tx_cold\tK_jvm/K_sbl\tjvm_warm_s\tsbl_warm_s\tx_warm\tnote\n' >> "$TSV"
wall() { /usr/bin/time -f '%e' -o "$W/time" timeout 300 "$@" > "$W/out" 2> "$W/err"; echo $? > "$W/rc"; tail -1 "$W/time"; }   # 300 s caps one run; time's report goes to its own file, never into the program's streams
ratio() { python3 -c 'import sys; a,b=sys.argv[1],sys.argv[2]; print("n/a" if "n/a" in (a,b) or "" in (a,b) or float(a)<0.05 or float(b)<=0 else f"{float(a)/float(b):.2f}")' "$1" "$2"; }
per() { python3 -c 'import sys; t1,tk,k=map(float,sys.argv[1:]); print(f"{max(tk-t1,0)/(k-1):.6f}")' "$@"; }
same() { [ "$(cat "$W/out")" = "$(cat "$ref")" ] && [ "$(cat "$W/rc")" = 0 ]; }
# kwarm <engine-cmd...>: prints "K per-repetition-seconds" for the engine's own K, or "n/a n/a"
kwarm() {
  local t1 tk k last=""
  t1="$(cd "$W" && wall "$@" w1.sno < /dev/null)"; same || { echo "n/a n/a"; return; }
  k=10
  while python3 "$HERE/bench_wrap_snobol4.py" "$kern" --mode iter --n "$k" -o "$W/wk.sno" 2>>"$W/gen"; do
    tk="$(cd "$W" && wall "$@" wk.sno < /dev/null)"; same || break
    last="$k $(per "$t1" "$tk" "$k")"
    python3 -c 'import sys; sys.exit(0 if float(sys.argv[2])-float(sys.argv[1]) >= 1.0 or int(sys.argv[3]) >= 1000000 else 1)' "$t1" "$tk" "$k" && { echo "$last"; return; }
    k=$((k*10))
  done
  if [ -n "$last" ] && python3 -c 'import sys; sys.exit(0 if float(sys.argv[1])*(int(sys.argv[2])-1) >= 1.0 else 1)' "${last#* }" "${last%% *}"; then echo "$last"; else echo "n/a n/a"; fi
}
pass=0; total=0; echo "BENCH snobol4jvm tree=$tree load=$load0 -- $(ls "$B"/*.sno | wc -l) kernels under $B"
for k in "$B"/*.sno; do
  n="$(basename "$k" .sno)"; ref="$B/$n.ref"; total=$((total+1)); note=""
  [ -f "$ref" ] || { printf '%s\tNO_REF\t\t\t\t\t\t\tno .ref beside the kernel\n' "$n" >> "$TSV"; echo "  NO_REF $n"; continue; }
  cp "$k" "$W/$n.sno"
  jc="$(cd "$W" && wall bash "$RUN" "$n.sno" < /dev/null)"; jrc=$?
  if [ "$(cat "$W/out")" = "$(cat "$ref")" ]; then v=PASS; pass=$((pass+1)); else v=FAIL; note="stdout differs from .ref; err1: $(grep -m1 . "$W/err" | cut -c1-120 | tr '\t' ' ')"; fi
  sc="$(cd "$W" && wall "$SBL" -bf "$n.sno" < /dev/null)"
  [ "$(cat "$W/out")" = "$(cat "$ref")" ] || note="${note:+$note; }sbl itself did not print the .ref"
  jw=n/a; sw=n/a; jK=n/a; sK=n/a; kern="$k"
  if [ "$v" = PASS ] && python3 "$HERE/bench_wrap_snobol4.py" "$k" --mode iter --n 1 -o "$W/w1.sno" 2>"$W/gen"; then
    read -r sK sw <<< "$(kwarm "$SBL" -bf)"; read -r jK jw <<< "$(kwarm bash "$RUN")"
    [ "$jw" = n/a ] && note="${note:+$note; }warm jvm n/a: no K at which its wrapper printed the .ref, exited 0 and spent 1 s inside 300 s"
    [ "$sw" = n/a ] && note="${note:+$note; }warm sbl n/a: no K at which the reference's wrapper printed the .ref and exited 0"
  elif [ "$v" = PASS ]; then note="${note:+$note; }warm n/a: $(grep -m1 . "$W/gen" | cut -c1-100)"; fi
  xw="$(python3 -c 'import sys; a,b=sys.argv[1],sys.argv[2]; print("n/a" if "n/a" in (a,b) or float(b)<=0 else f"{float(a)/float(b):.4f}")' "$sw" "$jw")"
  printf '%s\t%s\t%s\t%s\t%s\t%s/%s\t%s\t%s\t%s\t%s\n' "$n" "$v" "$jc" "$sc" "$(ratio "$sc" "$jc")" "$jK" "$sK" "$jw" "$sw" "$xw" "$note" >> "$TSV"
  printf '  %-4s %-20s cold jvm %6ss sbl %6ss x=%-5s  warm jvm %10ss (K=%s) sbl %10ss (K=%s) x=%s\n' "$v" "$n" "$jc" "$sc" "$(ratio "$sc" "$jc")" "$jw" "$jK" "$sw" "$sK" "$xw"
done
load1="$(cut -d' ' -f1-3 /proc/loadavg)"; printf '# load at end %s\n' "$load1" >> "$TSV"
sed 's/^/BENCH_TSV\t/' "$TSV"
echo "SNOBOL4JVM_BENCH pass=$pass total=$total tree=$tree load_start=$load0 load_end=$load1"
[ "$pass" = "$total" ] && exit 0 || exit 1
