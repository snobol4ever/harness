#!/usr/bin/env bash
# util_gc_share_callgrind.sh PROG.sno INPUT COPIES BAR_PCT -- THE COLLECTOR'S SHARE OF A PROGRAM'S INSTRUCTIONS, MEASURED UNDER
# CALLGRIND (load-invariant, CEO-743), GRADED AGAINST A BAR (hq_collector, the cost row of CEO-1574).
#
# The program runs in mode 3 at its DECLARED sizes (the <stem>.heap / <stem>.stack sidecars beside it, clause 8 (g)) with
# INPUT concatenated COPIES times on stdin, from corpus/include so its -INCLUDEs resolve.  callgrind_annotate --inclusive=yes
# reads gc_collect_ex's inclusive Ir and the program total; the share is printed with both counts and the collection count.
# rc 0 when the share is at or under BAR_PCT, rc 1 over it, rc 2 when callgrind, the program, its input or a reading is
# missing -- a share that could not be measured is never a pass.
set -uo pipefail
P="${1:-}"; IN="${2:-}"; N="${3:-}"; BAR="${4:-}"
[ -n "$P" ] && [ -n "$IN" ] && [ -n "$N" ] && [ -n "$BAR" ] || { echo "REFUSE(2): usage: $0 PROG.sno INPUT COPIES BAR_PCT"; exit 2; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="$(cd "$ROOT/.." && pwd)"
# The collector's share is a benchmark measurement: it runs with every diagnostic off unless the caller sets SCRIP_DIAG itself
# (Lon 2026-09-25, CEO-1262: "For benchmarks turn off diagnostics"); at the default the collector's self-checks (the trap ledger,
# the assert scan, the heap verify, the block index, the fix check) are counted inside gc_collect_ex -- on treebank at 64 copies
# 59.7 M of 340 M instructions read as the collector where 19.0 M are the collection (hq_runtime 2026-10-17).
export SCRIP_DIAG="${SCRIP_DIAG:-0}"
command -v valgrind >/dev/null && command -v callgrind_annotate >/dev/null || { echo "REFUSE(2): valgrind/callgrind_annotate absent"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSE(2): no $ROOT/scrip"; exit 2; }
[ -f "$P" ] && [ -f "$IN" ] || { echo "REFUSE(2): missing $P or $IN"; exit 2; }
stem="${P%.sno}"; hk=$(awk '{print $2}' "$stem.heap" 2>/dev/null | head -1); sk=$(awk '{print $2}' "$stem.stack" 2>/dev/null | head -1)
args=(); [ -n "$hk" ] && args+=("-d${hk}k"); [ -n "$sk" ] && args+=("-s${sk}k")
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
: > "$T/in"; for ((i = 0; i < N; i++)); do cat "$IN" >> "$T/in"; done
( cd "$S4E/corpus/include" 2>/dev/null || cd "$T"; SCRIP_GC_STATS=1 valgrind --tool=callgrind --callgrind-out-file="$T/cg.out" "$ROOT/scrip" "${args[@]}" "$P" < "$T/in" > "$T/out" 2> "$T/err" )
[ -s "$T/cg.out" ] || { echo "REFUSE(2): callgrind wrote no profile -- $(tail -2 "$T/err" | tr '\n' ' ')"; exit 2; }
callgrind_annotate --inclusive=yes "$T/cg.out" 2>/dev/null > "$T/ann"
tot=$(grep -m1 'PROGRAM TOTALS' "$T/ann" | grep -oE '^[0-9,]+' | tr -d ,)
gc=$(grep -E '[[:space:]]gc_collect_ex[[:space:]]|:gc_collect_ex[[:space:]]|\bgc_collect_ex \[' "$T/ann" | head -1 | grep -oE '^ *[0-9,]+' | tr -d ', ')
[ -n "$tot" ] && [ "$tot" -gt 0 ] || { echo "REFUSE(2): no program total in the annotation"; exit 2; }
[ -n "$gc" ] || gc=0
pct=$(awk -v g="$gc" -v t="$tot" 'BEGIN{printf "%.2f", 100 * g / t}')
ncol=$(grep -oE 'collections=[0-9]+' "$T/err" | tail -1 | cut -d= -f2)
echo "GC-SHARE prog=$(basename "$P") copies=$N heap_kb=${hk:-default} stack_kb=${sk:-default} gc_collect_ex_ir=$gc total_ir=$tot share=${pct}% collections=${ncol:-?} bar=${BAR}%"
awk -v p="$pct" -v b="$BAR" 'BEGIN{exit (p + 0 <= b + 0) ? 0 : 1}'
