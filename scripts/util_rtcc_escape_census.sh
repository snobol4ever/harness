#!/usr/bin/env bash
# util_rtcc_escape_census.sh — RC-6 PRECONDITION CENSUS (RTCC)
#
# RC-6 says: "a family already in asm (rtx_*.S) adopts the SCRIP convention
# natively; the registry reclassifies it NO-VENEER; its crossings become direct
# jumps/calls with zero writeback."
#
# That is SOUND ONLY IF the asm body can never reach C with claimed registers
# live and unsaved.  BLOCK-CANONICAL LAW: registers are a cache valid only
# inside generated code; a C function reading a claimed register reads garbage
# BY CONTRACT -- and, worse, clobbers it freely, so generated code resumes on
# garbage.  Every escape edge from an asm body into C is therefore a
# DISQUALIFIER for a free NO-VENEER reclassification.
#
# This script counts, per ported symbol, the edges that reach C:
#   (a) RTX_GATE(fam, c_fallback)  -> `cmp byte [rip+rtx_gate_fam],0; je c_fallback`
#       PRESENT ON EVERY GATED SYMBOL.  Taken whenever the family gate is OFF.
#   (b) explicit jmp/jcc/call to a c_* fallback or an @PLT target.
#
# EXIT: always 0 (informational census, blocks no seat -- s8 gate policy).
#
# ⛔ THE `.globl` TRAP: entry points are declared through the RTX_FUNC macro,
# not literal `.globl` lines.  A `grep .globl *.S` census returns ZERO symbols
# and reads as "nothing is ported".  Take the names from RTX_FUNC(...).
set -uo pipefail
RTXDIR="${RTXDIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)/src/runtime/rtx}"
[ -d "$RTXDIR" ] || { echo "no rtx dir: $RTXDIR"; exit 0; }
cd "$RTXDIR"
printf '=== RTCC RC-6 ESCAPE CENSUS (%s) ===\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
syms=$(grep -h 'RTX_FUNC(' ./*.S 2>/dev/null | sed 's/.*RTX_FUNC(//; s/).*//' | sort -u)
total=0; clean=0
printf '%-34s %6s %6s  %s\n' SYMBOL GATE EXPL VERDICT
printf '%-34s %6s %6s  %s\n' ---------------------------------- ------ ------ -------
while IFS= read -r s; do
  [ -n "$s" ] || continue
  body=$(awk -v S="RTX_FUNC($s)" -v E="RTX_ENDF($s)" 'index($0,S){f=1} f{print} index($0,E){f=0}' ./*.S)
  g=$(printf '%s\n' "$body" | grep -c 'RTX_GATE(')
  e=$(printf '%s\n' "$body" | grep -cE '(jmp|call|je|jne|jl|jle|jg|jge|ja|jb)[[:space:]]+(c_[a-zA-Z_0-9]+|[a-zA-Z_0-9]+@PLT)')
  total=$((total+1))
  if [ "$((g+e))" -eq 0 ]; then clean=$((clean+1)); v="ESCAPE-FREE (NO-VENEER eligible)"; else v="escapes -> C"; fi
  printf '%-34s %6s %6s  %s\n' "$s" "$g" "$e" "$v"
done <<< "$syms"
printf '\nPORTED SYMBOLS      : %s\n' "$total"
printf 'ESCAPE-FREE         : %s\n' "$clean"
printf 'NO-VENEER ELIGIBLE  : %s\n\n' "$clean"
cat <<'EOF'
READING: a symbol is eligible for a FREE NO-VENEER reclassification only at
GATE=0 and EXPL=0.  Any gated symbol is INELIGIBLE while its gate exists,
because the gate-off edge enters C unbracketed.  The enabling condition for
RC-6 is therefore NOT "ported" (RTX migration step 2) but "eradicated"
(step 3: gate folded ON, C fallback deleted) -- OR the asm body must itself
bracket its escape edges and preserve the claimed set on its fast path,
which is the cheaper RC-6b shape.
EOF
exit 0
