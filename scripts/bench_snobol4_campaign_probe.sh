#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_snobol4_campaign_probe.sh [--bar X] [--bud-ms N] [--scale N] -- THE SNOBOL4 SPEED CAMPAIGN'S CHEAP PROBE (ceo 2026-09-24, CEO-1246;
# Lon: "keep optimizing SNOBOL4 benchmarks until we are 2-3x faster than SPITBOL ... Use the work horse demos and benchmarks").
# WHAT IT MEASURES: four kernels' fixed-time twins (arith_loop, ident_call1, string_manip, table_access -- one per class: tight loop,
# call, string, table) and one workhorse demo (treebank at --scale copies of its input, default 256) under the CLEAN SPITBOL benchmark
# oracle (sbl_clean_bin, -bf) and SCRIP mode 4 (the prebuilt binary, the like-for-like arm; the
# demo also reads m3 for information). The multiple is SPITBOL time / SCRIP time on the same generated twin or the same input;
# the verdict is the GEOMETRIC MEAN over the five against --bar (default 2.0).
# EXIT 0 geomean >= bar; 1 below it; 2 REFUSED (oracle or binary missing, a build failure, a twin that did not print its ref, or
# the demo's outputs differing between the engines -- a speed number over a wrong answer is not a number).
# SCOUTING ONLY: ~20 s, never a board, appends and writes nothing; the published grids are test_snobol4_bench_suite.sh (kernels,
# README Language status) and bench_triangulate_demos_snobol4.sh (demos). ⛔ NO SIZE IS TYPED HERE (ceo CEO-1485 over the equal-arena
# arm, RULES.md clause 8 (g)(4)): each engine runs at its own defaults plus the UNIT's declaration -- a kernel's or treebank's .heap/.stack
# as SCRIP's -d/-s switches, its .oracle_args as sbl's -- read by lib_declared_arena.sh; the window is never typed. CRITERION CHANGED
# 2026-10-03: readings before ran sbl -s16m on the kernels and -d512m -i64m -s256m on treebank under ulimit -s 262144, and SCRIP's treebank
# under SCRIP_HEAP_KB=524288, a 512 MB WINDOW.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
. "$HERE/lib_oracle_flags.sh"
. "$HERE/lib_declared_arena.sh" || { echo "REFUSED(2): cannot load lib_declared_arena.sh"; exit 2; }
BAR=2.0; BUD=300; SCALE=256
while [ $# -gt 0 ]; do case "$1" in --bar) BAR="$2"; shift 2;; --bud-ms) BUD="$2"; shift 2;; --scale) SCALE="$2"; shift 2;; *) echo "usage: $0 [--bar X] [--bud-ms N] [--scale N]" >&2; exit 2;; esac; done
SBL="$(sbl_clean_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): clean SPITBOL oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
K="$S4E/corpus/benchmarks/snobol4"; D="$S4E/corpus/demos/snobol4/treebank"
[ -d "$K" ] && [ -f "$D/treebank.sno" ] || { echo "REFUSED(2): corpus kernels or the treebank demo missing"; exit 2; }
usrep() { grep -o 'BENCH mode=time.*' "$1" | head -1 | awk '{it=0; ns=0; mm=1; for(i=1;i<=NF;i++){split($i,a,"="); if(a[1]=="iters")it=a[2]; if(a[1]=="ns")ns=a[2]; if(a[1]=="mismatched")mm=a[2]} if(it>0 && mm==0) printf "%.3f", ns/it/1000; else print "REFUSE"}'; }
elapsed_ms() { grep -o 'elapsed_ns=[0-9]*' "$1" | head -1 | cut -d= -f2 | awk '{printf "%.3f", $1/1e6}'; }
WRAP="$ROOT/tools/bench_rusage"; [ -x "$WRAP" ] || gcc -O0 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || { echo "REFUSED(2): bench_rusage failed to build"; exit 2; }
echo "sizes: each unit's declaration over each engine's defaults (CEO-1485) -- CRITERION CHANGED 2026-10-03; earlier readings ran typed sbl sizes and a 512 MB SCRIP window"
printf "%-16s %12s %12s %8s\n" program "sbl" "scrip m4" multiple
LOGS=""
for k in arith_loop ident_call1 string_manip table_access; do
    python3 "$HERE/bench_wrap_snobol4.py" "$K/$k.sno" --mode time --bud-ms "$BUD" -o "$W/$k.sno" >/dev/null 2>&1 || { echo "REFUSED(2): twin generation failed for $k"; exit 2; }
    ( cd "$W" && "$ROOT/scrip" --compile -o "$W/$k.s" "$k.sno" </dev/null >/dev/null 2>&1 && gcc "$W/$k.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/$k.bin" ) 2>/dev/null || { echo "REFUSED(2): mode-4 build failed for $k"; exit 2; }
    ksw="$(declared_switches_beside "$K/$k.sno")" && koa="$(declared_oracle_args_beside "$K/$k.sno")" || { echo "REFUSED(2): $k's declared sizes are refused"; exit 2; }
    ( cd "$W" && timeout -k 5 60 "$SBL" $(sbl_lang_flags) $koa "$k.sno" </dev/null > "$W/$k.sbl.out" 2>&1 ); s=$(usrep "$W/$k.sbl.out")
    ( cd "$W" && timeout -k 5 60 "$W/$k.bin" $ksw </dev/null > "$W/$k.m4.out" 2>&1 ); m=$(usrep "$W/$k.m4.out")
    [ "$s" != REFUSE ] && [ "$m" != REFUSE ] || { echo "REFUSED(2): $k did not print its ref on both engines (sbl=$s m4=$m)"; exit 2; }
    x=$(awk -v a="$s" -v b="$m" 'BEGIN{printf "%.3f", a/b}'); LOGS="$LOGS $x"
    printf "%-16s %9s us %9s us %7.2fx\n" "$k" "$s" "$m" "$x"
done
: > "$W/tb.in"; for i in $(seq 1 "$SCALE"); do cat "$D/treebank.input" >> "$W/tb.in"; done
( cd "$D" && "$ROOT/scrip" --compile -o "$W/tb.s" treebank.sno </dev/null >/dev/null 2>&1 && gcc "$W/tb.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/tb.bin" ) 2>/dev/null || { echo "REFUSED(2): treebank mode-4 build failed"; exit 2; }
best() { local out=$1; shift; local b=""; for i in 1 2 3; do "$@" < "$W/tb.in" > "$out" 2> "$W/tb.err"; e=$(elapsed_ms "$W/tb.err"); [ -n "$e" ] && { [ -z "$b" ] || awk -v a="$e" -v c="$b" 'BEGIN{exit !(a<c)}'; } && b=$e; done; echo "$b"; }
tsw="$(declared_switches_beside "$D/treebank.sno")" && toa="$(declared_oracle_args_beside "$D/treebank.sno")" || { echo "REFUSED(2): treebank's declared sizes are refused"; exit 2; }
sbt=$( cd "$D" && best "$W/tb.sbl.out" "$WRAP" "$SBL" $(sbl_lang_flags) $toa treebank.sno )
m4t=$( best "$W/tb.m4.out" "$WRAP" "$W/tb.bin" $tsw )
cmp -s "$W/tb.sbl.out" "$W/tb.m4.out" || { echo "REFUSED(2): treebank output differs between sbl and scrip m4 (x$SCALE input)"; exit 2; }
[ -n "$sbt" ] && [ -n "$m4t" ] || { echo "REFUSED(2): treebank timing missing (sbl=$sbt m4=$m4t)"; exit 2; }
x=$(awk -v a="$sbt" -v b="$m4t" 'BEGIN{printf "%.3f", a/b}'); LOGS="$LOGS $x"
printf "%-16s %9s ms %9s ms %7.2fx   (whole program, x$SCALE input, best of 3, outputs identical)\n" "treebank" "$sbt" "$m4t" "$x"
G=$(echo "$LOGS" | awk '{s=0; n=0; for(i=1;i<=NF;i++){s+=log($i); n++}; printf "%.3f", exp(s/n)}')
awk -v g="$G" -v b="$BAR" 'BEGIN{ printf "CAMPAIGN_PROBE geomean=%.2fx bar=%.2fx verdict=%s (tree ", g, b, (g>=b?"GREEN":"RED") }'; echo "$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -dirty), $(date '+%F %T'), load $(uptime | sed 's/.*average: //' | cut -d, -f1), bud_ms=$BUD)"
awk -v g="$G" -v b="$BAR" 'BEGIN{exit (g>=b)?0:1}'
