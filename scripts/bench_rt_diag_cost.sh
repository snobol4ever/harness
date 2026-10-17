#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_rt_diag_cost.sh -- WHAT THE SHIPPED LIBRARY PAYS FOR ITS DIAGNOSTICS WHILE THEY ARE OFF (ceo CEO-1390, 2026-10-01; the cfo's
# row runtime-the-shipped-library-pays-for-its-diagnostics-while-they-are-off-...). The DONE-WHEN of that row.
#
# THE QUESTION. SCRIP_DIAG=0 turns the runtime's diagnostic switches off, but the code RT_DIAG=1 compiles in still runs: the
# collector's stack-walk census counters (gc_walk_words, gc_walk_interior), gc_nospine_cell, gc_assert_check. Lon's CEO-1262 word,
# "turn off all diagnostic code for benchmarks", is read by CEO-1390 as: the shipped library carries no diagnostic code that costs
# instructions while the diagnostic is off. The bars keep grading the shipped library, which is the point of this arm.
#
# THE ARM. treebank x1024 in mode 4 (the sizes the unit declares in fixtures/rt_diag_cost/treebank_x1024.heap and .stack: 131072 KB heap, 8192 KB stack -- the x1024 input overflows treebank's own 4096 KB stack, measured twice at 4096 and 8192), ONE binary run twice: once against
# the shipped out/libscrip_rt.so, once against the same tree built with RT_OPT plus -DRT_DIAG=0. The second is built in THIS
# checkout under its own RT_TAG (out/libscrip_rt-<tag>.so, objects cached under out/rt_pic-<tag>), the way the auditor gate builds
# its knob-on library. It compiles exactly the sources of the shipped one with one define added, so it is "the same tree" and costs
# a scratch worktree nothing: cold about 3.5 min at -j8 on 2026-10-01, cached after.
# Both libraries are READ BACK, never assumed: the shipped one must carry the [ZGC-WALK] telemetry string an RT_DIAG=1 build
# compiles in, and the scouting one must not. Otherwise the arm would compare a build with itself and REFUSES.
# THE COUNT is user-mode retired instructions from perf stat (instructions:u), the hardware Ir. It is load-immune: two runs of one
# library agreed to 0.0003% on 2026-10-01. It is not a wall-clock predictor, and the line says so. callgrind would count the
# same thing at roughly 100x the cost per arm on 5.7e9 instructions.
# Both runs' stdout must be byte-identical and non-empty, or the arm REFUSES: a cost over a wrong answer is not a cost.
#
#   bench_rt_diag_cost.sh [BAR_PCT]   default 2: GREEN while the diagnostics cost at most BAR_PCT percent of the shipped Ir.
# EXIT 0 GREEN, 1 RED (the gap exceeds the bar), 2 REFUSED (no perf, a build failed, a stamp disagrees, the outputs differ).
set -uo pipefail
G=bench_rt_diag_cost
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
refuse() { echo "⛔ $G REFUSE(2): $*"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
BAR="${1:-2}"
case "$BAR" in ''|*[!0-9.]*) refuse "the bar must be a percentage, got '$BAR'";; esac
PERF=""
for c in perf /usr/lib/linux-tools/*/perf; do
    { command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; } || continue
    "$c" stat -x, -e instructions:u -o /dev/null true >/dev/null 2>&1 && { PERF="$c"; break; }
done
[ -n "$PERF" ] || refuse "no perf on this box counts instructions:u (tried perf and /usr/lib/linux-tools/*/perf)"
BASE="$(make -s -C "$ROOT" buildinfo 2>/dev/null | sed -n 's/^RT_OPT *: *//p' | sed 's/ *$//')"
[ -n "$BASE" ] || refuse "make buildinfo printed no RT_OPT"
D0OPT="$BASE -DRT_DIAG=0"
TAG="$(make -s -C "$ROOT" RT_OPT="$D0OPT" buildinfo 2>/dev/null | sed -n 's/^RT_TAG *: *//p' | sed 's/ *$//')"
[ -n "$TAG" ] || refuse "make buildinfo printed no RT_TAG for RT_OPT='$D0OPT'"
T=$(mktemp -d) || refuse "mktemp"
trap 'rm -rf "$T"' EXIT TERM INT
make -C "$ROOT" RT_OPT="$D0OPT" "out/libscrip_rt-$TAG.so" > "$T/build.log" 2>&1 || { tail -5 "$T/build.log"; refuse "the -DRT_DIAG=0 library did not build"; }
SHIP="$(readlink -f "$ROOT/out/libscrip_rt.so")"; D0LIB="$ROOT/out/libscrip_rt-$TAG.so"
[ -r "$SHIP" ] && [ -r "$D0LIB" ] || refuse "a library is missing ($SHIP, $D0LIB)"
grep -q -a 'ZGC-WALK' "$SHIP" || refuse "the shipped library carries no [ZGC-WALK] string, so it reads RT_DIAG=0 -- this arm would compare a build with itself"
grep -q -a 'ZGC-WALK' "$D0LIB" && refuse "the -DRT_DIAG=0 library still carries [ZGC-WALK] -- the define did not reach the runtime"
D="$S4E/corpus/demos/snobol4/treebank"; P="$D/treebank.sno"; IN="$D/treebank.input"
[ -f "$P" ] && [ -f "$IN" ] || refuse "missing $P or $IN"
: > "$T/in"; for ((i = 0; i < 1024; i++)); do cat "$IN" >> "$T/in"; done
"$ROOT/scrip" --compile -o "$T/d.s" "$P" < /dev/null 2> "$T/cc.err" && gcc "$T/d.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/d.prog" 2>> "$T/cc.err" || { head -3 "$T/cc.err"; refuse "treebank did not build in mode 4"; }
mkdir -p "$T/ship" "$T/d0"; ln -s "$SHIP" "$T/ship/libscrip_rt.so"; ln -s "$D0LIB" "$T/d0/libscrip_rt.so"
. "$HERE/lib_declared_arena.sh" || refuse "no lib_declared_arena.sh"
SW="$(declared_switches_beside "$HERE/fixtures/rt_diag_cost/treebank_x1024.sno")" || refuse "the treebank x1024 unit's .heap/.stack sidecars are refused"; [ -n "$SW" ] || refuse "the treebank x1024 unit declares no size (fixtures/rt_diag_cost/treebank_x1024.heap/.stack)"
run() { ( cd "$S4E/corpus/include" && LD_LIBRARY_PATH="$T/$1" "$PERF" stat -x, -e instructions:u -o "$T/$1.stat" "$T/d.prog" $SW < "$T/in" > "$T/$1.out" 2> /dev/null ) || return 1
        grep -E ',instructions' "$T/$1.stat" | head -1 | cut -d, -f1; }
s=$(run ship) || refuse "the shipped run failed"; d=$(run d0) || refuse "the -DRT_DIAG=0 run failed"
case "$s$d" in ''|*[!0-9]*) refuse "perf printed no instruction count (shipped='$s' scouting='$d')";; esac
[ -s "$T/ship.out" ] && cmp -s "$T/ship.out" "$T/d0.out" || refuse "the two runs' stdout differs or is empty -- no cost over a wrong answer"
awk -v s="$s" -v d="$d" -v bar="$BAR" -v opt="$BASE" -v tag="$TAG" 'BEGIN{ g = (s - d) * 100 / s;
    printf "treebank x1024 mode 4: shipped RT_OPT=%s RT_DIAG=1 Ir=%d · scouting the same tree -DRT_DIAG=0 (RT_TAG %s) Ir=%d · the diagnostics cost %.2f%% of the shipped Ir while off (bar %s%%; instructions, not time): %s\n", opt, s, tag, d, g, bar, (g <= bar) ? "GREEN" : "RED";
    exit (g <= bar) ? 0 : 1 }'
