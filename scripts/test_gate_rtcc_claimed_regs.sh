#!/usr/bin/env bash
# test_gate_rtcc_claimed_regs.sh — RTCC CLAIMED-REGISTER COLLISION GATE (GOAL-RTCC, RC-5 protection).
#
# WHY THIS GATE EXISTS. RC-5 assigns VM globals into registers that were previously ordinary scratch.
# A register claim is a GLOBAL fact about the whole emitted program, but templates are edited by many
# concurrent seats, and NOTHING in the build objects when a template grabs a claimed register as scratch.
# That is not hypothetical: RC-5-GVA claimed r9 = RT_GVA_VA, AB-2 then used r9 as anchor scratch in
# bb_define.cpp, and the resulting fibonacci SIGSEGV cost sessions s6 and s7 (bisect + one-line fix,
# FINDING-2026-08-09-CLAUDE-SN46-RTCC-RC5-FLOATER-R9-RCX-FIX.md).  This gate makes that class MECHANICAL.
#
# THE INVARIANT.  Under RTCC_GLOBAL_R9_GVA with the killswitch ON, r9 holds RT_GVA_VA at EVERY point in
# generated code.  A template write to r9 opens a window with two distinct hazards:
#   (H1) LOCAL   — a GVARQ() access [r9+off] inside that window reads from a wrong base.
#   (H2) GLOBAL  — if a veneered call falls inside the window, x86_rtcc_wb_bin's `mov [rax+48], r9` stores
#                  the CLOBBERED value into the canonical block slot, and the matching reload propagates it.
#                  RT_GVA_VA is then destroyed for the REST OF THE PROCESS, not merely this template.
#   H2 is why rtcc_init.c's "seeded once; no companion writes needed anywhere" comment is not by itself a
#   guarantee: the veneer's own writeback IS a companion write on every crossing.
#
# WHAT IS CHECKED (textual, deliberately):  a full dataflow proof is out of scope for a grep gate, so this
# reports the HAZARD SURFACE and hard-fails only the COLLISION CLASS — files that both write a live-claimed
# register and read through GVARQ.  Those are the files where H1/H2 can co-occur inside one emitted region.
# A flagged file is NOT automatically a defect; it is a file that MUST be cleared by probe (RULES.md forbids
# conviction by code-reading) or entered in the registry with a justification.  Op-filtering is a capability
# registry, not a silencer: each line records WHO cleared it and HOW.
#
# LIVE CLAIMS ONLY.  Registers claimed-but-unassigned (no VM global living in them yet) are harmless to
# clobber today and are reported as INFORMATIONAL.  Add a register to LIVE_CLAIMS the moment RC-5 assigns a
# global to it — that one edit is what buys the next assignment this protection.
#
# Usage: bash ../harness/scripts/test_gate_rtcc_claimed_regs.sh [--informational]
#   default        : HARD GATE (V2-5, gate honesty) — exit 1 if any non-registered file is in the
#                    collision class. --strict is still accepted as a no-op spelling of the default.
#   --informational: print hazard surface + collision class, exit 0 regardless of collisions.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
strict=1   # V2-5 (gate honesty): STRICT IS THE DEFAULT.  Nothing in ../harness/scripts/ ever passed --strict,
[ "${1:-}" = "--informational" ] && strict=0   # so the enforcement arm was unreachable and this gate could not say no.
[ "$strict" = "0" ] && echo "⛔ --informational: verdict NOT enforced."
# ⭐ V2-5 COVERAGE FLOOR (gate honesty): examining NOTHING must never read the same as examining everything.
. "$HERE/lib_gate.sh"
gate_floor "$(ls "$HERE"/../../SCRIP/src/emitter/*.c "$HERE"/../../SCRIP/src/emitter/*.cpp "$HERE"/../../SCRIP/src/templates/{bb,xa}/*.cpp "$HERE"/../../SCRIP/src/runtime/*.c 2>/dev/null | wc -l)" 100 "source files under src/ -- an empty tree is UNPROVEN(2), not a pass"


TPL="src/templates"
REGISTRY="../harness/scripts/rtcc_claimed_reg_registry.txt"

# LIVE_CLAIMS — registers with a VM global actually assigned by an RC-5 rung.  reg:global:rung
LIVE_CLAIMS="r9:RT_GVA_VA:RC-5-GVA"

# strip_comments FILE — code only, so a comment naming a register does not count as a live use.
strip_comments() { sed -E 's://.*$::' "$1" | perl -0777 -pe 's{/\*.*?\*/}{}gs'; }

wl_has() { [ -f "$REGISTRY" ] && grep -qE "^[[:space:]]*$1[[:space:]]" "$REGISTRY"; }

rc=0
echo "=== RTCC CLAIMED-REGISTER COLLISION GATE ==="
echo

for claim in $LIVE_CLAIMS; do
  reg="${claim%%:*}"; rest="${claim#*:}"; glob="${rest%%:*}"; rung="${rest##*:}"
  echo "--- LIVE CLAIM: $reg = $glob  ($rung) ---"

  # Destination-position writes: x86("<mnem>", "<reg>", ...) — the AB-2 defect shape.
  # Plus RDQ("<reg>", ...) — using the claimed register as a NON-GVA base pointer, equally a collision.
  # Sub-register spellings ($reg d/w/b) are writes to the SAME claimed register (a 32-bit write zeroes the
  # upper half) — the s101 match-family hole: bb_match_{any,break,notany,span,span_var,breakx} carried
  # needle-len in "r9d" for sessions, invisible to the exact-"r9" pattern, and every SPAN/BREAK/ANY INLINE
  # box killed the GVA base for whatever GVA reader ran next without an intervening veneer reload
  # (json/treebank/calculator/claws5 demo SIG11 class, witness corpus/probe/rtcc/rtcc_span_gva_defer).
  wpat="x86\\(\"(mov|mov32|movabs|movzx|movsx|lea|pop|xor|and|or|add|sub|imul|shl|shr|neg|not|inc|dec)\", *\"$reg[dwb]?\""
  rpat="RDQ\\(\"$reg[dwb]?\""

  writers=""; surface=0
  for f in "$TPL"/*.cpp; do
    n=$(strip_comments "$f" | grep -cE "$wpat|$rpat")
    if [ "$n" -gt 0 ]; then writers="$writers $(basename "$f")"; surface=$((surface + n)); fi
  done

  # ⛔ NEVER `| grep -q` UNDER pipefail (s11): grep -q exits on first match, closing the pipe; the upstream
  # sed|perl then takes SIGPIPE(141) and `set -o pipefail` propagates that, so a MATCH READS AS A MISS.
  # Measured on this tree: 3 large templates flipped (bb_call 14/20, bb_call_proc_staged 16/20,
  # bb_define 13/20), readers ranged 5..8 against a truth of 8 -- and the WORST offender is the very
  # file s8 convicted.  grep -c reads to EOF, cannot SIGPIPE the upstream, and is what line ~67 already uses.
  gvausers=""
  for f in "$TPL"/*.cpp; do
    n=$(strip_comments "$f" | grep -c "GVARQ(")
    if [ "$n" -gt 0 ]; then gvausers="$gvausers $(basename "$f")"; fi
  done

  echo "HAZARD SURFACE : $surface write/base-use site(s) of $reg across$( [ -n "$writers" ] && echo "$writers" || echo " (none)")"
  echo "GVARQ READERS  :$( [ -n "$gvausers" ] && echo "$gvausers" || echo " (none)")"

  # COLLISION CLASS = writes the claimed register AND reads through GVARQ.
  collide=""
  for f in $writers; do
    case " $gvausers " in *" $f "*) collide="$collide $f";; esac
  done

  if [ -z "$collide" ]; then
    echo "COLLISION CLASS: EMPTY — no template both clobbers $reg and reads [$reg+off]."
  else
    echo "COLLISION CLASS:$collide"
    for f in $collide; do
      if wl_has "$f"; then
        echo "  [REGISTRYED] $f — $(grep -E "^[[:space:]]*$f[[:space:]]" "$REGISTRY" | head -1 | cut -c1-160)"
      else
        echo "  [UNCLEARED]   $f — clobbers $reg AND reads GVARQ. Clear by probe or registry with justification."
        rc=1
      fi
    done
  fi
  echo
done

if [ "$strict" = "1" ]; then
  [ "$rc" = "0" ] && echo "GATE: PASS (strict)" || echo "GATE: FAIL (strict) — uncleared collision-class file(s) above."
  exit "$rc"
fi
echo "GATE: INFORMATIONAL (pass --strict to enforce). rc would be $rc."
exit 0
