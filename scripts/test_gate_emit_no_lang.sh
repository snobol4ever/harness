#!/usr/bin/env bash
# test_gate_emit_no_lang.sh — LANG-BLIND EMITTER gate (RULES.md line 86 + GOAL-IR-IMMUTABLE-EMIT RUNG LANG-GLOBAL ERADICATION).
#
# DOCTRINE: language-specific code is for PARSER and LOWER — they KNOW their language implicitly.
# EMITTER and TEMPLATES are past language and into PLATFORM: they condition ONLY on the IR graph
# (op kinds, operands, payloads, edge stamps) and platform state, never on which language produced
# the graph. This gate asserts that NO language-identity IDENTIFIER exists anywhere the emitter or
# templates could read it — no global, no enum symbol, no graph language field. Removed = prevented
# forever: any reintroduction fails this gate (and, for the deleted globals/enum, fails to compile).
#
# IDENTIFIER-SCOPED, NOT STRING-SCOPED: we strip C comments and double-quoted string literals before
# grepping, so a diagnostic message ("... Icon-only reset ...") or a dormant-backend output literal
# ("Snobol4.Runtime.Boxes", "java/lang/String") is NOT a violation — only a live CODE reference to a
# banned identifier is. The banned tokens are also case-specific (g_lang / LANG_ / IR_LANG_ /
# rt_set_lang / is_<language>), which alone keeps them out of those strings.
#
# Usage: bash ../harness/scripts/test_gate_emit_no_lang.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"

ROOTS="src/emitter src/templates"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
gate_floor "$(ls src/emitter/*.c src/emitter/*.cpp src/emitter/*.h src/templates/*.c src/templates/{bb,xa}/*.cpp src/templates/{bb,xa,x86}/*.h 2>/dev/null | wc -l)" 100 "emitter/template source files -- V2-5: an empty tree must not read as LANG-BLIND"

# The banned identifier set (case-sensitive C identifiers, word-boundaried):
#   g_lang            — the deleted language global
#   rt_set_lang       — the deleted runtime language setter (baked into emitted asm)
#   LANG_<UPPER>      — the frontend language enum (LANG_SNO / LANG_ICN / ...)
#   IR_LANG_<UPPER>   — the deleted IR-spine language enum
#   is_<language>     — any per-language boolean (is_icon / is_snobol4 / is_prolog / ...)
#   ->lang / .lang    — the deleted graph/stage2 language field access
BANNED='\bg_lang\b|\brt_set_lang\b|\bIR_LANG_[A-Z]|\bLANG_[A-Z]|\bis_(icon|snobol4?|prolog|raku|snocone|rebus|pascal|scrip)\b|(->|\.)lang\b'

# strip: block comments, line comments, then double-quoted string literals — so only live code remains.
strip() { perl -0777 -pe 's{/\*.*?\*/}{}gs; s{//[^\n]*}{}g; s{"(\\.|[^"\\])*"}{""}g' "$1"; }

VIOL=""
for f in $(find $ROOTS -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.h' \) 2>/dev/null); do
  hits="$(strip "$f" | grep -nE "$BANNED" 2>/dev/null)"
  [ -n "$hits" ] && VIOL="$VIOL"$'\n'"$(printf '%s' "$hits" | sed "s#^#$f:#")"
done
VIOL="$(printf '%s' "$VIOL" | grep -c . )"

if [ "$VIOL" -eq 0 ]; then
  echo "OK: LANG-BLIND — no language-identity identifier in src/emitter or src/templates."
  echo "    (emitter and templates condition only on the IR graph and platform — never on language.)"
  exit 0
fi
echo "FAIL: LANG-BLIND — $VIOL language-identity reference(s) found in emitter/templates:"
for f in $(find $ROOTS -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.h' \) 2>/dev/null); do
  hits="$(strip "$f" | grep -nE "$BANNED" 2>/dev/null)"
  [ -n "$hits" ] && printf '%s\n' "$hits" | sed "s#^#  $f:#"
done
echo "--- language is for PARSER and LOWER; the later stages must not know or be able to know it. Remove the identifier. ---"
exit 1
