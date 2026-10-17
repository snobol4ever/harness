#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_prolog_ix_ab.sh — PL-SPEED-5 first-arg indexing A/B (same-lib twin binaries, interleaved medians).
# Twin discipline (GOAL-PROLOG-BB "RAIL METHOD TRAP"): ONE compiler + ONE libscrip_rt.so build; the baseline
# twin is EMITTED with SCRIP_NO_IX=1 (guards not lowered), the post twin with the default (guards on); both
# assemble+link against the SAME lib; runs interleave A,B,A,B x5; the per-benchmark cell is the MEDIAN.
# Usage: bash ../harness/scripts/bench_prolog_ix_ab.sh [--n N] [bench ...]   (default: qsort nrev deriv tak fib)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
LIBRT="$ROOT/out/libscrip_rt.so"
VR=/tmp/ixsrc
OUT=/tmp/ixab; mkdir -p "$OUT"
BENCHES=("$@"); [ ${#BENCHES[@]} -eq 0 ] && BENCHES=(qsort nrev deriv tak fib)
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "${SCRIP:-${SCRIP_BIN:-$(dirname "$0")/../../SCRIP/scrip}}" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
build_one() { # $1=src $2=outbin $3=env(0/1 SCRIP_NO_IX)
    if [ -x "$2" ] && [ "$2" -nt "$SCRIP" ]; then return 0; fi
    local W; W=$(mktemp -d /tmp/ixb_XXXXXX)
    ( cd "$W" && SCRIP_NO_IX=$3 timeout -k 5 30 "$SCRIP" --compile --target=x86 "$1" > p.s 2> scrip.err < /dev/null ) || { echo "  EMIT-FAIL ($1 NO_IX=$3)"; sed -n '1,5p' "$W/scrip.err"; rm -rf "$W"; return 1; }
    ( cd "$W" && as --64 -o p.o p.s && gcc -no-pie -o "$2" p.o "$LIBRT" -lm -lstdc++ -Wl,-rpath,"$(dirname "$LIBRT")" ) 2> "$W/lderr" || { echo "  AS/LD-FAIL"; head -5 "$W/lderr"; rm -rf "$W"; return 1; }
    cp "$W/p.s" "$2.s"; rm -rf "$W"; return 0
}
for b in "${BENCHES[@]}"; do
    src="$VR/$b.pl"; [ -f "$src" ] || { echo "SKIP $b (no $src)"; continue; }
    build_one "$src" "$OUT/${b}_base" 1 || continue
    build_one "$src" "$OUT/${b}_ix"   0 || continue
    at=(); bt=()
    for i in 1 2 3 4 5; do
        s0=$(date +%s%N); timeout -k 5 60 "$OUT/${b}_base" > /dev/null 2>&1; s1=$(date +%s%N); ta=$(awk -v d=$((s1-s0)) 'BEGIN{printf "%.3f", d/1e9}')
        s0=$(date +%s%N); timeout -k 5 60 "$OUT/${b}_ix"   > /dev/null 2>&1; s1=$(date +%s%N); tb=$(awk -v d=$((s1-s0)) 'BEGIN{printf "%.3f", d/1e9}')
        at+=("$ta"); bt+=("$tb")
    done
    ma=$(printf '%s\n' "${at[@]}" | sort -n | sed -n 3p)
    mb=$(printf '%s\n' "${bt[@]}" | sort -n | sed -n 3p)
    r=$(awk -v a="$ma" -v b="$mb" 'BEGIN { if (a > 0) printf "%.3f", b / a; else print "nan" }')
    g=$(grep -c "rt_pl_dop_ix_g" "$OUT/${b}_ix.s" 2>/dev/null || echo 0)
    echo "$b  base=${ma}s  ix=${mb}s  ix/base=${r}  guards_in_s=${g}  (A: ${at[*]} | B: ${bt[*]})"
done
