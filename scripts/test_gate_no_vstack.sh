#!/usr/bin/env bash
# test_gate_no_vstack.sh — SCRIP-WIDE value-stack ZERO-CHECK (VSX ladder, Lon directive 2026-05-31).
#
# SCRIP has NO value stack. SNOBOL4/Icon/Prolog all use Byrd Boxes; g_vstack and its apparatus must not
# exist. This gate greps (C/C++ comments stripped) ALL of src/ for the value-stack apparatus and reports
# the live code-reference count.
#
#   VSX-1..VSX-7 : INFORMATIONAL — prints the current count as the apparatus is dismantled rung by rung.
#   VSX-8        : HARD GATE — pass --strict; exits 1 if the count is not 0.
#
# The trail (rt_pl_trail_*, g_resolve_trail) is NOT a value stack and is NOT matched here (it is the
# legitimate Prolog binding-undo ledger — KEEP).
#
# Usage: bash ../harness/scripts/test_gate_no_vstack.sh [--strict]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
strict=1   # V2-5 (gate honesty): STRICT IS THE DEFAULT (VSX-8 is the hard gate and nothing invoked it).
[ "${1:-}" = "--informational" ] && strict=0
[ "$strict" = "0" ] && echo "⛔ --informational: verdict NOT enforced."
# ⭐ V2-5 COVERAGE FLOOR (gate honesty): examining NOTHING must never read the same as examining everything.
. "$HERE/lib_gate.sh"
gate_floor "$(ls "$HERE"/../src/emitter/*.c "$HERE"/../src/emitter/*.cpp "$HERE"/../src/templates/{bb,xa}/*.cpp "$HERE"/../src/runtime/*.c 2>/dev/null | wc -l)" 100 "source files under src/ -- an empty tree is UNPROVEN(2), not a pass"


# strip_comments FILE — FILE with /* ... */ block comments and // line comments removed (code only, so a
# comment explaining the eradication does not count as a live reference).
strip_comments() { sed -E 's://.*$::' "$1" | perl -0777 -pe 's{/\*.*?\*/}{}gs'; }

apparatus='g_vstack|vstack_push|vstack_pop|vstack_peek|rt_vstack_ops_t|rt_vstack_depth|rt_vstack_pop|VSTACK_CAP'
total=0
report=""
for f in $(grep -rlE "$apparatus" src/ --include="*.c" --include="*.cpp" --include="*.h" 2>/dev/null); do
  h=$(strip_comments "$f" | grep -cE "$apparatus")
  if [ "$h" -gt 0 ]; then
    total=$((total + h))
    report="${report}  ${h}\t${f}\n"
  fi
done

echo "=== VSX no-vstack zero-check (code references, comments stripped) ==="
if [ "$total" -gt 0 ]; then
  printf "%b" "$report" | sort -rn
fi
echo "TOTAL value-stack code references in src/: $total  (target: 0)"

if [ "$strict" -eq 1 ]; then
  if [ "$total" -ne 0 ]; then
    echo "FAIL (--strict): g_vstack apparatus still present; VSX not complete."
    exit 1
  fi
  echo "PASS (--strict): g_vstack fully eradicated from SCRIP."
fi
exit 0
