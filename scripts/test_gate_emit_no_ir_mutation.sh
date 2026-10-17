#!/usr/bin/env bash
# test_gate_emit_no_ir_mutation.sh — IRM-0 gate for GOAL-IR-IMMUTABLE-EMIT.md
# The emitter READS IR; it never mutates it. Hard count = op-writes + IR_LIT/IR_EXEC field-writes
# across src/emitter/ + src/templates/. [C] runtime-query-driven retag is reported INFORMATIONAL (emit.cpp only;
# distinguishing an emit-time query from an emitted call needs per-site review).
# Baseline at Ground Zero #5: A=34 op-writes, B=11 field-writes (all in emit_bb.c) -> hard total 45.
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
EMIT="$ROOT/src/emitter"
TPL="$ROOT/src/templates"
strip() { sed -E ':a;s@/\*[^*]*\*+([^/*][^*]*\*+)*/@@;ta'; }

scan() {  # prints per-file breakdown to STDERR; echoes ONLY the numeric total to STDOUT
  local pat="$1" total=0 n f
  for f in "$EMIT"/*.cpp "$TPL"/*.cpp; do
    [ -f "$f" ] || continue
    n=$(strip < "$f" | grep -aEc "$pat" 2>/dev/null); n=${n:-0}
    [ "$n" -gt 0 ] && printf "    %-32s %s\n" "$(basename "$f")" "$n" >&2
    total=$((total + n))
  done
  echo "$total"
}
scan_one() { strip < "$EMIT/emit.cpp" | grep -aEc "$1" 2>/dev/null; }

echo "=== IRM-0: emitter IR-mutation gate ==="
echo "[A] op writes ( ->op = ) across src/emitter + src/templates:"
A=$(scan '[-]>op[[:space:]]*=[[:space:]]*[A-Za-z0-9_]')
echo "[B] IR_LIT/IR_EXEC field writes ( .field = , not == ) across src/emitter + src/templates:"
B=$(scan 'IR_(LIT|EXEC)\([^)]*\)\.[a-z_]+[[:space:]]*=[[:space:]]*[^=]')
C=$(scan_one 'rt_(proc_is_|builtin_is_)[a-z_]+[[:space:]]*\('); C=${C:-0}

HARD=$((A + B))
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_floor "$(ls "$(dirname "$0")"/../src/emitter/*.cpp "$(dirname "$0")"/../src/templates/{bb,xa}/*.cpp 2>/dev/null | wc -l)" 100 "emitter/template source files"
echo "-------------------------------------------"
echo "A op-writes=$A   B field-writes=$B   ->  HARD TOTAL = $HARD   (target 0)"
echo "[C informational] emit-time runtime-query refs in emit.cpp = $C (review per IRM-4)"
if [ "$HARD" -eq 0 ]; then echo "PASS: the emitter never mutates IR."; exit 0; fi
echo "FAIL: $HARD IR-mutation site(s) in src/emitter+src/templates — see GOAL-IR-IMMUTABLE-EMIT.md IRM-1..IRM-6."
exit 1
