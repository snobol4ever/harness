#!/usr/bin/env bash
# test_gate_bb_emit_blind.sh — EMIT-BLIND gate for GOAL-BB-FIXUP.md
# Counts direct neighbor dereferences (pBB->[αβγω]) in BB_templates/*.cpp (comments stripped).
# INFORMATIONAL at baseline; --strict enforces zero (FIX-FENCE requirement).
# Baseline snapshot 2026-06-04: 12 files, 132 direct pBB->[αβγω] refs
# + 5 files with local-alias neighbor walks (lf->t / fin->.*->t / a0->t).
# Usage: bash ../harness/scripts/test_gate_bb_emit_blind.sh [--strict]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
strict=1   # V2-5 (gate honesty): STRICT IS THE DEFAULT.  grep proved nothing in the repo invoked this at all.
[ "${1:-}" = "--informational" ] && strict=0
[ "$strict" = "0" ] && echo "⛔ --informational: verdict NOT enforced."
# ⭐ V2-5 COVERAGE FLOOR (gate honesty): examining NOTHING must never read the same as examining everything.
. "$HERE/lib_gate.sh"
gate_floor "$(ls "$HERE"/../../SCRIP/src/emitter/*.c "$HERE"/../../SCRIP/src/emitter/*.cpp "$HERE"/../../SCRIP/src/templates/{bb,xa}/*.cpp "$HERE"/../../SCRIP/src/runtime/*.c 2>/dev/null | wc -l)" 100 "source files under src/ -- an empty tree is UNPROVEN(2), not a pass"

strip() { perl -0777 -pe 's{/\*.*?\*/}{}gs; s{//[^\n]*}{}g' "$1"; }
total_direct=0
total_alias=0
report_direct=""
report_alias=""
for f in src/templates/bb/bb_*.cpp; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    direct=$(strip "$f" | grep -cE 'pBB->[αβγω]' || true)
    alias=$(strip  "$f" | grep -cE '\b(lf|fin|a0|a1|arm|node)->(α|β|γ|ω|t)\b' || true)
    [ "$direct" -gt 0 ] && { total_direct=$((total_direct + direct)); report_direct="$report_direct $name($direct)"; }
    [ "$alias"  -gt 0 ] && { total_alias=$((total_alias + alias));   report_alias="$report_alias $name($alias)"; }
done
total=$((total_direct + total_alias))
echo "=== BB EMIT-BLIND gate (neighbor dereferences in templates) ==="
printf "  Direct pBB->[αβγω] refs: %d" "$total_direct"
[ -n "$report_direct" ] && printf "  [%s]" "$report_direct" || true
echo ""
printf "  Alias neighbor-walk refs: %d" "$total_alias"
[ -n "$report_alias" ] && printf "  [%s]" "$report_alias" || true
echo ""
printf "  TOTAL emit-blind refs: %d  (baseline 2026-06-04: 132 direct + alias)\n" "$total"
if [ "$strict" -eq 1 ]; then
    if [ "$total" -ne 0 ]; then
        echo "FAIL (--strict): $total emit-blind neighbor references remain; FIX-FENCE requires zero."
        exit 1
    fi
    echo "PASS (--strict): zero emit-blind neighbor references — EMIT-BLIND clean."
else
    echo "(informational — run with --strict to gate at zero)"
fi
exit 0
