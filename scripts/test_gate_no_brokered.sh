#!/usr/bin/env bash
# ../harness/scripts/test_gate_no_brokered.sh — BROK-3 fence: the emit-side brokered convention is DELETED.
# Counts live (comment-stripped) references to the abolished symbols across src/.
# Criterion: total == 0 (HARD). bb_box_fn keeps (zeta, int entry) — survivors at rt.c p->fn(fb,0) blob alpha-entry.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE/../../SCRIP"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
# ⛔ THE POPULATION IS COUNTED BEFORE IT IS JUDGED (coo 2026-09-18, the cto's finding, seat10's 2026-08-23 list).
# An empty src/ makes the find yield nothing, the loop never runs, and "MUST be 0" certifies the brokered
# convention abolished across a tree this gate never read.  Zero files scanned is COULD NOT MEASURE.
files=0
while IFS= read -r f; do files=$((files+1)); done < <(find "$ROOT/src" -name '*.c' -o -name '*.cpp' -o -name '*.h')
gate_floor "$files" 1 "src/ source file(s)"
total=0; hits=""
while IFS= read -r f; do
    n=$(sed -e 's|//.*||' -e 's|/\*[^*]*\*/||g' "$f" | grep -cE 'bb_build_brokered|EMIT_BINARY_BROKERED|g_bb_brokered|\bBB_BROKERED\b|\bBB_WIRED\b|flat_brokered' || true)
    if [ "$n" -gt 0 ]; then total=$((total+n)); hits="$hits $f($n)"; fi
done < <(find "$ROOT/src" -name '*.c' -o -name '*.cpp' -o -name '*.h')
echo "brokered-convention live refs (code, comments stripped): $total  (MUST be 0)"
if [ "$total" -ne 0 ]; then echo "OFFENDERS:$hits"; echo "GATE FAIL."; exit 1; fi
echo "OK: emit-side brokered convention abolished (zero live code references)."
