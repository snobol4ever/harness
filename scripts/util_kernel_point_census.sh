#!/usr/bin/env bash
# util_kernel_point_census.sh <lang> <max_ms> <kernel>... -- THE POINT CONVENTION, MEASURED: each named benchmark kernel of
# corpus/benchmarks/<lang> is run ONCE in mode 3 under its declared -d/-s sidecars (<kernel>.heap, <kernel>.stack: "<name><TAB><kb>"),
# its wall clock printed in ms, and the census reads RED (rc 1) when any single run exceeds <max_ms> -- Lon's point convention is
# 0.5 to 5 s per point (RULES.md THE KERNEL CONVENTION; CEO-1264), so a kernel whose one run takes 20 s makes every three-angle grading of it
# cost twelve runs of 20 s (CEO-1564: RakBench's 3293 s a pass were four such kernels). rc 2 when the kernel, the binary or the corpus is
# missing: a census that cannot measure says so. Mode 3 only: the kernel's own work, no harness angles.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; W="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$W/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSED(2): no scrip at $SCRIP"; exit 2; }
[ $# -ge 3 ] || { echo "usage: $0 <lang> <max_ms> <kernel>..."; exit 2; }
lang="$1"; max="$2"; shift 2
case "$lang" in snobol4) ext=sno;; icon) ext=icn;; prolog) ext=pl;; pascal) ext=pas;; raku) ext=raku;; snocone) ext=sc;; rebus) ext=reb;; *) echo "⛔ REFUSED(2): unknown language $lang"; exit 2;; esac
D="$W/../corpus/benchmarks/$lang"; [ -d "$D" ] || { echo "⛔ REFUSED(2): no corpus at $D"; exit 2; }
rc=0
for k in "$@"; do
    f="$D/$k.$ext"; [ -f "$f" ] || { echo "⛔ REFUSED(2): no kernel $f"; exit 2; }
    sw=()
    [ -f "$D/$k.heap" ] && sw+=("-d$(cut -f2 "$D/$k.heap" | head -1)k")
    [ -f "$D/$k.stack" ] && sw+=("-s$(cut -f2 "$D/$k.stack" | head -1)k")
    s=$(date +%s%N); (cd "$D" && timeout -k 5 120 "$SCRIP" "${sw[@]}" "$f" </dev/null >/dev/null 2>&1); r=$?; e=$(date +%s%N)
    ms=$(( (e - s) / 1000000 ))
    if [ "$ms" -gt "$max" ]; then v=RED; rc=1; else v=ok; fi
    printf '  %-36s %7d ms  rc=%-3s %s\n' "$k" "$ms" "$r" "$v"
done
[ "$rc" -eq 0 ] && echo "GREEN: every named $lang kernel runs once within $max ms" || echo "RED: a named $lang kernel's single run exceeds $max ms (the point convention is 500 to 5000 ms)"
exit $rc
