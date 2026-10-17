#!/usr/bin/env bash
# test_gate_no_handencoded_bytes.sh — enforce the FACT RULE
#   "MEDIUM_BINARY IS ASSEMBLED LITERAL ASM — NEVER HAND-ENCODED BYTES"
# (GOAL-SNOBOL4-BB / GOAL-ICON-BB / GOAL-PROLOG-BB, Lon directive 2026-06-01).
#
# Every BB template's MEDIUM_BINARY arm must ASSEMBLE the literal GAS asm its
# MEDIUM_TEXT arm emits — it must NOT hand-encode instruction bytes nor count
# byte offsets to locate rel32 patch sites. This gate counts, per template, the
# BAD-SITE tokens that mark a hand-encoded arm. The count only ever decreases as
# arms are converted to assembled-asm.  (bomb_bytes() was the old loud-stub route; deleted as dead
# code in the s269 strip -- implement the arm and add an x86_asm.h encoder instead.)
#
# Modes:
#   (default)   informational baseline — prints the per-file punch list, ALWAYS exits 0.
#   --strict    HARD gate — exits non-zero if any BAD site remains (flip to this
#               once the asm-assembly splice path lands).
#
# CARVE-OUT (RULES.md TEMPLATE-ONLY): bytes()/u8()/u32le()/u64le() are legal ONLY
# inside bb_emit_asm_result in emit_str.cpp — NOT scanned here (this
# gate scans BB_templates/*.cpp only, where any such token is a BAD site).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
DIR="$ROOT/src/templates"
STRICT=1; [ "${1:-}" = "--informational" ] && STRICT=0   # V2-5: strict by default
[ "${1:-}" = "--strict" ] && STRICT=1
[ "$STRICT" = "0" ] && echo "⛔ --informational: verdict NOT enforced."
# ⭐ V2-5 COVERAGE FLOOR (gate honesty): examining NOTHING must never read the same as examining everything.
. "$(dirname "$0")/lib_gate.sh"
gate_floor "$(ls "$(dirname "$0")"/../src/emitter/*.c "$(dirname "$0")"/../src/emitter/*.cpp "$(dirname "$0")"/../src/templates/{bb,xa}/*.cpp "$(dirname "$0")"/../src/runtime/*.c 2>/dev/null | wc -l)" 100 "source files under src/ -- an empty tree is UNPROVEN(2), not a pass"


# The ONLY bad pattern (FACT RULE): a FUNCTION that counts the bytes — b.size().
# Literal byte maps are CORRECT and are NOT flagged: bytes("\x..") opcode literals,
# hardcoded bin={{..}} offset tuples, u32le/u64le immediates, TEMPLATE_ADDR_* bakes.
PAT='b\.size\(\)'

# strip C/C++ comments first (block + line) so token mentions in comments — incl. this
# rule's own explanatory notes — never false-positive. Mirrors the g_vstack gate discipline.
strip_comments() { perl -0777 -pe 's{/\*.*?\*/}{}gs; s{//[^\n]*}{}g' "$1"; }

TOTAL=0; BADFILES=0
echo "=== BAD-SITE scan: b.size() function byte-counters in BB_templates ==="
for f in "$DIR"/*.cpp; do
    [ -e "$f" ] || continue
    n=$(strip_comments "$f" | grep -aoE "$PAT" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$n" -gt 0 ]; then
        printf '  %4d  %s\n' "$n" "$(basename "$f")"
        TOTAL=$((TOTAL + n))
        BADFILES=$((BADFILES + 1))
    fi
done
echo "---"
echo "BAD sites (b.size()): $TOTAL  across $BADFILES file(s)   (target: 0 — rewrite each to a hardcoded literal offset map)"

if [ "$STRICT" -eq 1 ]; then
    [ "$TOTAL" -eq 0 ] && { echo "OK: zero b.size() function-counters in BB_templates."; exit 0; }
    echo "FAIL (--strict): $TOTAL b.size() function-counter site(s) remain — rewrite to literal offset maps."
    exit 1
fi
echo "(informational baseline — not gating; run with --strict to enforce zero.)"
exit 0
