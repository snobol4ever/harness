#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_snobol4_bar.sh -- THE SPEED ROW'S CRITERION (ceo CEO-1276, 2026-09-26; Lon: "mint some delegated tasks to implement those improvements and
# enhance the SCRIP to run even faster"): ONE kernel or ONE demo, the bare multiple SPITBOL time / SCRIP mode-4 time (RULES.md FACT RULE, CEO-1242),
# against a bar. It is the DONE-WHEN of every row the 2026-09-26 why-slower profile minted, so a row closes on the same instrument that found it.
#
#   kernel K BAR        K's fixed-time twin under the three-angle harness (test_snobol4_bench_suite.sh) on a mktemp fixture -- never the corpus
#                       directory, so never a board (CEO-547) and no row is written -- BENCH_ORACLE_ARM=1, BAR_BUD_MS (500) per point, BAR_ITER_N (3)
#                       iterations, both engines at SPITBOL's own defaults (-d128m -i1m -s4m, CEO-1261). The multiple is the harness's own two
#                       time-twin readings, sbl and m4, taken in the same run.
#   demo D BAR          D's whole program on the README's input scale, best of BAR_REPS (3) elapsed under tools/bench_rusage, each engine at
#                       its own defaults plus the DEMO's declaration -- its .oracle_args on sbl -bf, its .heap/.stack as the mode-4 binary's
#                       -d/-s (ceo CEO-1485, RULES.md clause 8 (g)(4); CRITERION CHANGED 2026-10-03: readings before ran BAR_SW
#                       "-d512m -i64m -s256m" on both under ulimit -s 262144, the equal-arena arm the law overtook); stdout must be
#                       byte-identical on both engines or the run REFUSES -- a speed number over a wrong answer is not a number.
#
# EXIT 0 at or above the bar (GREEN), 1 below it (RED, the row is open), 2 REFUSED (no binary, no oracle, no twin printed, outputs differ).
# The oracle is the clean SPITBOL benchmark oracle, sbl_clean_bin (lib_oracle_flags.sh), never the monitor-hooked correctness fork.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
. "$HERE/lib_oracle_flags.sh"
refuse() { echo "⛔ bench_snobol4_bar REFUSE(2): $*"; exit 2; }
[ $# -ge 3 ] || { echo "usage: $0 kernel <name> <bar> | demo <name> <bar>"; exit 2; }
KIND=$1; NAME=$2; BAR=$3
SCRIP="$ROOT/scrip"; [ -x "$SCRIP" ] || refuse "no ./scrip (make first)"
SBL="$(sbl_clean_bin)"; [ -x "$SBL" ] || refuse "clean SPITBOL oracle missing ($SBL)"
WRAP="$ROOT/tools/bench_rusage"; [ -x "$WRAP" ] || gcc -O2 -o "$WRAP" "$ROOT/tools/bench_rusage.c" || refuse "bench_rusage did not build"
T=$(mktemp -d) || refuse "mktemp"; trap 'rm -rf "$T"' EXIT
. "$HERE/lib_perf_fmt.sh"
refuse_timing() { local g; if g="$(perf_load_guard)"; then echo "⛔ bench_snobol4_bar REFUSE(2) $g: $*"; else echo "⛔ bench_snobol4_bar REFUSE(2): $* ($g)"; fi; exit 2; }
verdict() { awk -v x="$1" -v bar="$BAR" -v what="$2" -v st="$(perf_build_stamp)" 'BEGIN{printf "%s reads %.2fx SPITBOL in mode 4 (bar %.2fx): %s · %s\n", what, x, bar, (x>=bar)?"GREEN":"RED", st; exit (x>=bar)?0:1}'; }
case "$KIND" in
  kernel)
    BD="$S4E/corpus/benchmarks/snobol4"; [ -f "$BD/$NAME.sno" ] || refuse "no kernel $BD/$NAME.sno"
    cp "$BD/$NAME.sno" "$T/"; [ -f "$BD/$NAME.ref" ] && cp "$BD/$NAME.ref" "$T/"; [ -f "$BD/harness.inc" ] && cp "$BD/harness.inc" "$T/"
    ( cd "$ROOT" && BENCH_SNOBOL4_DIR="$T" BENCH_ORACLE_ARM=1 BENCH_ITER_N="${BAR_ITER_N:-3}" BENCH_BUD_MS="${BAR_BUD_MS:-500}" bash ../harness/scripts/test_snobol4_bench_suite.sh ) > "$T/log" 2>&1
    s=$(grep -E "scouting $NAME sbl: BENCH mode=time" "$T/log" | sed -E 's/.*iters=([0-9]+) ns=([0-9]+).*/\2 \1/' | head -1)
    m=$(grep -E "scouting $NAME m4: BENCH mode=time" "$T/log" | sed -E 's/.*iters=([0-9]+) ns=([0-9]+).*/\2 \1/' | head -1)
    [ -n "$s" ] && [ -n "$m" ] || { tail -5 "$T/log"; refuse_timing "the harness printed no time twin for $NAME (sbl='$s' m4='$m')"; }
    grep -qE "^$NAME +m4 +PASS +PASS +PASS +PASS" "$T/log" || refuse "$NAME did not PASS every angle in mode 4 (a number over a wrong answer is not a number)"
    x=$(awk -v s="$s" -v m="$m" 'BEGIN{split(s,a," "); split(m,b," "); printf "%.4f", (a[1]/a[2])/(b[1]/b[2])}')
    awk -v s="$s" -v m="$m" 'BEGIN{split(s,a," "); split(m,b," "); printf "kernel %s: SPITBOL %.2f us/rep, m4 %.2f us/rep (fixed-time twins, %s ms points)\n", "'"$NAME"'", a[1]/a[2]/1000, b[1]/b[2]/1000, "'"${BAR_BUD_MS:-500}"'"}'
    verdict "$x" "kernel $NAME" ;;
  demo)
    D="$S4E/corpus/demos/snobol4"
    . "$HERE/lib_declared_arena.sh" || refuse "cannot load lib_declared_arena.sh -- the one reader of a declared size"
    case "$NAME" in
      claws5) P=$D/claws5/claws5.sno; IN=$D/claws5/CLAWS5inTASA.dat; N=16;; treebank) P=$D/treebank/treebank.sno; IN=$D/treebank/treebank.input; N=1024;;
      json) P=$D/json/json.sno; IN=$D/json/citm_catalog.json; N=1;; porter) P=$D/porter/porter.sno; IN=$D/porter/porter.input; N=4;;
      calculator-1) P=$D/calculator/calculator-1.sno; IN=$D/calculator/calculator.input; N=4;; calculator-2) P=$D/calculator/calculator-2.sno; IN=$D/calculator/calculator.input; N=4;;
      beauty) P=$D/beauty/beauty.sno; IN=$D/beauty/beauty.sno; N=1;;
      *) refuse "unknown demo $NAME (claws5 treebank json porter calculator-1 calculator-2 beauty)";;
    esac
    [ -f "$P" ] && [ -f "$IN" ] || refuse "missing $P or $IN"
    SWD="$(declared_switches_beside "$P")" && OAD="$(declared_oracle_args_beside "$P")" || refuse "$NAME: its declared sizes are refused"
    : > "$T/in"; for ((i=0;i<N;i++)); do cat "$IN" >> "$T/in"; done
    "$SCRIP" --compile -o "$T/d.s" "$P" < /dev/null 2> "$T/cc.err" && gcc "$T/d.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/d.prog" 2>> "$T/cc.err" || { head -3 "$T/cc.err"; refuse "$NAME did not build in mode 4"; }
    best() { local tag=$1 b=999999999999 i e; shift; for ((i=0;i<${BAR_REPS:-3};i++)); do ( cd "$S4E/corpus/include" && "$WRAP" timeout -k 5 600 "$@" < "$T/in" > "$T/$tag.out" 2> "$T/err" ); e=$(grep -oE 'elapsed_ns=[0-9]+' "$T/err" | tail -1 | cut -d= -f2); [ -n "$e" ] || { echo ""; return; }; [ "$e" -lt "$b" ] && b=$e; done; echo "$b"; }
    s=$(best sbl "$SBL" -bf $OAD "$P"); m=$(best m4 "$T/d.prog" $SWD)
    [ -n "$s" ] && [ -n "$m" ] || refuse_timing "a run printed no BENCH_RUSAGE line (sbl='$s' m4='$m')"
    cmp -s "$T/sbl.out" "$T/m4.out" && [ -s "$T/m4.out" ] || refuse "$NAME: outputs differ between sbl -bf and mode 4 (or are empty) -- no multiple over a wrong answer"
    x=$(awk -v s="$s" -v m="$m" 'BEGIN{printf "%.4f", s/m}')
    awk -v s="$s" -v m="$m" 'BEGIN{printf "demo %s: SPITBOL %.1f ms, m4 %.1f ms (best of %s, %s)\n", "'"$NAME"'", s/1e6, m/1e6, "'"${BAR_REPS:-3}"'", "'"sbl [$OAD] m4 [$SWD], the declarations -- CRITERION CHANGED 2026-10-03, CEO-1485"'"}'
    verdict "$x" "demo $NAME" ;;
  *) refuse "kind must be kernel or demo";;
esac
