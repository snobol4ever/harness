#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_prolog_bar.sh -- THE PROLOG SPEED ROW'S CRITERION (ceo CEO-1278, 2026-09-26; the Prolog twin of bench_snobol4_bar.sh and
# bench_icon_bar.sh): ONE kernel under corpus/benchmarks/prolog/bench, the bare multiple rival time / SCRIP mode-4 time (RULES.md
# FACT RULE, CEO-1242) against a bar, read from angle 1 of the Prolog three-angle harness (test_bench_prolog_timed.sh: a live doubling
# search for the largest N whose between+fail loop completes within BAR_BUD_MS (500); the multiple is read on the SELF-MEASURED WORK per
# iteration inside the generated bracket, the two-number basis (CEO-1281 -- the CPU rate carried mode 3's in-process compile); the kernel's
# single-shot output is held to its .ref on every engine, under its declared -d/-s sidecars, before it is timed) for the one kernel, in ONE
# run -- no board, no row written.
#   kernel K BAR [swi|gnu]   K is the kernel's file stem (tak, deriv, nreverse, ...); the rival is swipl (default) or gprolog
#                            ("$(gprolog_bin)" --consult-file, the byte-code WAM) or gplc (GNU Prolog compiled native, CEO-1281). A kernel whose arm reads SKIP, CRASH or no rate REFUSES: no multiple over an
#                            uncited reading. BAR_MODE=m3 grades mode 3 instead of mode 4.
# EXIT 0 at or above the bar (GREEN), 1 below it (RED, the row is open), 2 REFUSED (no binary, no rival, no citable reading).
set -u
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
refuse() { echo "⛔ bench_prolog_bar REFUSE(2): $*"; exit 2; }
. "$HERE/lib_perf_fmt.sh" 2>/dev/null || refuse "cannot load lib_perf_fmt.sh -- the one authority for a load stamp and the load guard"
refuse_timing() { local g; if g="$(perf_load_guard)"; then echo "⛔ bench_prolog_bar REFUSE(2) $g: $*"; else echo "⛔ bench_prolog_bar REFUSE(2): $* ($g)"; fi; exit 2; }
[ $# -ge 3 ] && [ "$1" = kernel ] || { echo "usage: $0 kernel <stem> <bar> [swi|gnu]"; exit 2; }
NAME=$2; BAR=$3; RIVAL="${4:-swi}"; MODE="${BAR_MODE:-m4}"
case "$RIVAL" in swi|gnu|gplc) ;; *) refuse "rival must be swi, gnu ("$(gprolog_bin)" --consult-file, the byte-code WAM) or gplc (GNU Prolog compiled native)";; esac
[ -x "$ROOT/scrip" ] || refuse "no ./scrip (make first)"; command -v swipl > /dev/null || refuse "swipl absent"; gprolog_bin >/dev/null || exit 2
T=$(mktemp -d) || refuse "mktemp"; trap 'rm -rf "$T"' EXIT
( cd "$ROOT" && KERNELS="$NAME" TIME_BUDGET_MS="${BAR_BUD_MS:-500}" bash ../harness/scripts/test_bench_prolog_timed.sh ) > "$T/log" 2>&1
row=$(grep -E "^$NAME[[:space:]]" "$T/log" | head -1); [ -n "$row" ] || { tail -4 "$T/log" | cut -c1-160; refuse_timing "angle 1 printed no row for $NAME"; }   # the FIRST row is the rates table (SKIP / ok is read there)
read -r _k _g _gp _s _m3 _m4 check <<<"$row"
# ⭐ THE WORK BASIS (CEO-1281): the multiple is read from angle 1's THIRD dashed block -- SELF-MEASURED WORK PER ITERATION (us/it) inside the
#   generated bracket, the two-number basis -- not from the CPU rates of the first, which carry mode 3's in-process compile as a per-iteration
#   cost and made the mode-3 column uncitable (14 of 23 DISAGREE at CEO-1278). us/it is a COST: the multiple is rival us / SCRIP us.
wrow=$(awk -v k="$NAME" '/^-{5,}/{blk++; next} blk==3 && $1==k {print; exit}' "$T/log"); [ -n "$wrow" ] || { echo "$row" | cut -c1-160; refuse_timing "angle 1 printed no WORK row for $NAME (its rates row reads: $check)"; }
read -r _k gnu gplc swi m3 m4 <<<"$wrow"
case "$RIVAL" in swi) rv=$swi;; gnu) rv=$gnu;; gplc) rv=$gplc;; esac; case "$MODE" in m3) mine=$m3;; *) mine=$m4;; esac
for v in "$rv" "$mine"; do case "$v" in ''|SKIP|DARK|CRASH*|DNF*|-|NA|*[!0-9.]*) echo "$wrow" | cut -c1-160; refuse_timing "$NAME has no citable work reading on $RIVAL and $MODE (a SKIP, a DARK bracket or no number: $rv / $mine)";; esac; done
awk -v r="$rv" -v m="$mine" -v bar="$BAR" -v k="$NAME" -v rival="$RIVAL" -v mode="$MODE" -v chk="$check" 'BEGIN{x=r/m; printf "kernel %s: %s %.2f us/it, %s %.2f us/it (angle 1, self-measured work per iteration), rates row %s; reads %.2fx %s in mode %s (bar %.2fx): %s\n", k, (rival=="swi")?"swipl":(rival=="gplc")?"gplc":"gprolog", r, mode, m, chk, x, (rival=="swi")?"swipl":(rival=="gplc")?"gplc":"gprolog", substr(mode,2), bar, (x>=bar)?"GREEN":"RED"; exit (x>=bar)?0:1}'
