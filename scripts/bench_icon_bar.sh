#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_icon_bar.sh -- THE ICON SPEED ROW'S CRITERION (ceo CEO-1276, 2026-09-26; the Icon twin of bench_snobol4_bar.sh): ONE kernel under
# corpus/benchmarks/icon, the bare multiple Arizona iconx time / SCRIP mode-4 time (RULES.md FACT RULE, CEO-1242) against a bar, read from
# the three-angle harness bench_triangulate_icon.sh (the fixed-time twin's microseconds per iteration, BAR_BUD_MS (500) per point,
# BAR_N (5) iterations per fixed-iteration point) in ONE run with --out to a mktemp TSV -- no board, no row written.
#   kernel K BAR       K is the kernel's file stem (bench_icnagg_field_isolate, concord, geddump, ...). A kernel whose two timed angles
#                      DISAGREE, or that does not PASS every angle in every engine, REFUSES: no multiple over an uncited reading. A kernel
#                      the harness iterates one process per iteration (PROC: its iconx arm reports no in-process work time) is read on
#                      process ELAPSED per iteration instead, and the line says so.
#   demo jtran BAR     the JCON translator (17 modules, corpus/demos/icon/jcon/jtran.icn) built by icont and by SCRIP mode 4 (and run in
#                      mode 3), its preprocessor stage on JCON's own gen_bc.icn to stdout, best of BAR_REPS (5) elapsed, outputs
#                      byte-compared across the three; the multiple is iconx time / SCRIP time in BAR_MODE (m4, or m3 for the row on
#                      the in-process compile).
# EXIT 0 at or above the bar (GREEN), 1 below it (RED, the row is open), 2 REFUSED (no binary, no oracle, no citable reading).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_perf_fmt.sh"
refuse() { echo "⛔ bench_icon_bar REFUSE(2): $*"; exit 2; }
refuse_timing() { local g; if g="$(perf_load_guard)"; then echo "⛔ bench_icon_bar REFUSE(2) $g: $*"; else echo "⛔ bench_icon_bar REFUSE(2): $* ($g)"; fi; exit 2; }
[ $# -ge 3 ] && { [ "$1" = kernel ] || [ "$1" = demo ]; } || { echo "usage: $0 kernel <stem> <bar> | demo jtran <bar>"; exit 2; }
KIND=$1; NAME=$2; BAR=$3; [ -x "$ROOT/scrip" ] || refuse "no ./scrip (make first)"
T=$(mktemp -d) || refuse "mktemp"; trap 'rm -rf "$T"' EXIT
if [ "$KIND" = demo ]; then
  [ "$NAME" = jtran ] || refuse "the only demo this criterion knows is jtran"
  export SCRIP_DIAG=0; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"; PKG="$S4E/corpus/packages/icon/jcon-compiler"; D="$S4E/corpus/demos/icon/jcon"
  ICONT=/home/resources/icon-master/bin/icont; [ -x "$ICONT" ] || refuse "no icont at $ICONT"; WRAP="$ROOT/tools/bench_rusage"; [ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || refuse "bench_rusage did not build"
  MODS=$(sed -n 's/^[[:space:]]*link[[:space:]]*"\([^"]*\)".*$/\1/p' "$D/jtran.icn" | sed 's|.*/||' | sed "s|^|$PKG/|; s|$|.icn|" | tr '\n' ' ')
  ( cd "$T" && "$ICONT" -s -o "$T/jtran.oracle" $MODS ) > "$T/icont.log" 2>&1 || refuse "icont did not build the oracle"
  ( cd "$D" && "$ROOT/scrip" --compile --out="$T/jtran.s" jtran.icn < /dev/null ) > "$T/m4c.log" 2>&1 && gcc "$T/jtran.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/jtran.m4" 2>> "$T/m4c.log" || refuse "jtran did not build in mode 4"
  cp "$PKG/gen_bc.icn" "$T/gen_bc.icn"; MODE="${BAR_MODE:-m4}"
  best() { local tag=$1 dir=$2; shift 2; local b=999999999999 i e; for ((i=0;i<${BAR_REPS:-5};i++)); do ( cd "$dir" && "$WRAP" timeout -k 5 600 "$@" > "$T/$tag.out" 2> "$T/$tag.err" ); e=$(grep -oE 'elapsed_ns=[0-9]+' "$T/$tag.err" | tail -1 | cut -d= -f2); [ -n "$e" ] && [ "$e" -lt "$b" ] && b=$e; done; echo "$b"; }
  so=$(best oracle "$T" "$T/jtran.oracle" preproc "$T/gen_bc.icn" : stdout)
  if [ "$MODE" = m3 ]; then sm=$(best m3 "$D" "$ROOT/scrip" jtran.icn -- preproc "$T/gen_bc.icn" : stdout); cmp -s "$T/oracle.out" "$T/m3.out" || refuse "jtran preproc: mode-3 output differs from the oracle's"
  else sm=$(best m4 "$T" "$T/jtran.m4" preproc "$T/gen_bc.icn" : stdout); cmp -s "$T/oracle.out" "$T/m4.out" || refuse "jtran preproc: mode-4 output differs from the oracle's"; fi
  [ -s "$T/oracle.out" ] || refuse "the oracle printed nothing"
  awk -v st="$(perf_build_stamp)" -v s="$so" -v m="$sm" -v bar="$BAR" -v mode="$MODE" 'BEGIN{x=s/m; printf "demo jtran (preproc gen_bc.icn, best of %s): iconx %.1f ms, %s %.1f ms; reads %.2fx iconx in mode %s (bar %.2fx): %s · %s\n", "'"${BAR_REPS:-5}"'", s/1e6, mode, m/1e6, x, substr(mode,2), bar, (x>=bar)?"GREEN":"RED", st; exit (x>=bar)?0:1}'
  exit $?
fi
( cd "$ROOT" && BUDGET_MS="${BAR_BUD_MS:-500}" BENCH_N_DEFAULT="${BAR_N:-5}" bash ../harness/scripts/bench_triangulate_icon.sh --out "$T/t.tsv" "$NAME" ) > "$T/log" 2>&1
[ -s "$T/t.tsv" ] || { tail -5 "$T/log"; refuse_timing "the harness wrote no TSV for $NAME"; }
read -r ix m4 loop <<<"$(awk -F'\t' -v k="$NAME" 'NR>1 && $1==k && $2=="iconx" && $13=="PASS" && $12 ~ /^AGREE/ {ix=$9*1000/$8} NR>1 && $1==k && $2=="m4" && $13=="PASS" && $12 ~ /^AGREE/ {m4=$9*1000/$8} NR>1 && $1==k {loop=$3} END{print ix+0, m4+0, loop}' "$T/t.tsv")"
BASIS="fixed-time twins, in-process work"
if [ "$loop" = PROC ] && [ "$ix" = 0 ]; then
  read -r ix m4 <<<"$(awk -F'\t' -v k="$NAME" 'NR>1 && $1==k && $2=="iconx" && $13=="PASS" && $11>0 && $8>0 {ix=$11*1000/$8} NR>1 && $1==k && $2=="m4" && $13=="PASS" && $11>0 && $8>0 {m4=$11*1000/$8} END{print ix+0, m4+0}' "$T/t.tsv")"
  BASIS="one process per iteration: process elapsed per iteration, the fixed-time angle"
fi
[ "$ix" != 0 ] && [ "$m4" != 0 ] || { grep -E "^$NAME" "$T/log" | cut -c1-160; refuse_timing "$NAME has no citable reading on iconx and m4 (a DISAGREE or a non-PASS angle; raise BAR_N for a sub-millisecond kernel)"; }
awk -v st="$(perf_build_stamp)" -v ix="$ix" -v m4="$m4" -v bar="$BAR" -v k="$NAME" -v basis="$BASIS" 'BEGIN{x=ix/m4; printf "kernel %s: iconx %.1f us/it, m4 %.1f us/it (%s); reads %.2fx iconx in mode 4 (bar %.2fx): %s · %s\n", k, ix, m4, basis, x, bar, (x>=bar)?"GREEN":"RED", st; exit (x>=bar)?0:1}'
