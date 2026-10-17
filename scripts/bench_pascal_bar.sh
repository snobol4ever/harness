#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_pascal_bar.sh -- THE PASCAL SPEED ROW'S CRITERION (ceo CEO-1281, 2026-09-26; the Pascal twin of bench_prolog_bar.sh): ONE kernel under
# corpus/benchmarks/pascal, the bare multiple fpc time / SCRIP mode-4 time (RULES.md FACT RULE, CEO-1242) against a bar, read from angle 1 of the
# Pascal three-angle harness (test_bench_pascal_timed.sh: the WORK slope in us per rep fitted over a x1/x4/x16 triple of reps, a COST, the reps=1
# output held to the .ref first, the kernel run under its declared -d/-s sidecars) for the one kernel, in ONE run -- no board, no row written.
#   kernel K BAR       K is the kernel's file stem (bubble, queens, whet, ...). A kernel whose arm reads SKIP, NA or NONLINEAR REFUSES: no
#                      multiple over an uncited reading. BAR_MODE=m3 grades mode 3 instead of mode 4. The rival is fpc -O2 at its released
#                      default (the one legitimate -O2 on this box, RULES.md § NO -O2 BUILDS).
# EXIT 0 at or above the bar (GREEN), 1 below it (RED, the row is open), 2 REFUSED (no binary, no fpc, no citable reading).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
refuse() { echo "⛔ bench_pascal_bar REFUSE(2): $*"; exit 2; }
. "$HERE/lib_perf_fmt.sh" 2>/dev/null || refuse "cannot load lib_perf_fmt.sh -- the one authority for a load stamp and the load guard"
refuse_timing() { local g; if g="$(perf_load_guard)"; then echo "⛔ bench_pascal_bar REFUSE(2) $g: $*"; else echo "⛔ bench_pascal_bar REFUSE(2): $* ($g)"; fi; exit 2; }
[ $# -ge 3 ] && [ "$1" = kernel ] || { echo "usage: $0 kernel <stem> <bar>"; exit 2; }
NAME=$2; BAR=$3; MODE="${BAR_MODE:-m4}"
[ -x "$ROOT/scrip" ] || refuse "no ./scrip (make first)"; . "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "cannot load lib_oracle_flags.sh"; fpc_bin > /dev/null || refuse "fpc absent"
T=$(mktemp -d) || refuse "mktemp"; trap 'rm -rf "$T"' EXIT
( cd "$ROOT" && KERNELS="$NAME" bash ../harness/scripts/test_bench_pascal_timed.sh ) > "$T/log" 2>&1
row=$(grep -E "^$NAME[[:space:]]" "$T/log" | head -1); [ -n "$row" ] || { tail -4 "$T/log" | cut -c1-160; refuse_timing "angle 1 printed no row for $NAME"; }
read -r _k fpc m3 m4 check <<<"$row"
case "$MODE" in m3) mine=$m3;; *) mine=$m4;; esac
for v in "$fpc" "$mine"; do case "$v" in ''|SKIP|NA|MISSING|*[!0-9.]*) echo "$row" | cut -c1-160; refuse_timing "$NAME has no citable work reading on fpc and $MODE (a SKIP, an NA or NONLINEAR arm: $fpc / $mine)";; esac; done
awk -v r="$fpc" -v m="$mine" -v bar="$BAR" -v k="$NAME" -v mode="$MODE" -v chk="$check" 'BEGIN{x=r/m; printf "kernel %s: fpc -O2 %.2f us/rep, %s %.2f us/rep (angle 1, the WORK slope over a x1/x4/x16 triple), check %s; reads %.4fx fpc in mode %s (bar %.4fx): %s\n", k, r, mode, m, chk, x, substr(mode,2), bar, (x>=bar)?"GREEN":"RED"; exit (x>=bar)?0:1}'
