#!/usr/bin/env bash
# ⛔⭐ CONTROL EDGES LIVE ON PORTS (ceo CEO-696, on Lon's 2026-09-13 word that SCRIP uses a
# PHYSICAL GRAPH AND TEMPLATES and has no labels -- "that is JCON. Totally different.").
#
# THE TEST THIS ENFORCES (CEO-695): IF A NODE'S CONTROL EDGES CANNOT BE FOLLOWED BY THE
# WALKER'S ORDINARY PORT RULE, IT IS NOT A NODE -- it is an instruction wearing a node's
# shape, and it belongs in a template.
#
# ⛔ WHY A RATCHET AND NOT A BAN: an operand push is not automatically the defect. Three of
# the four live cases are sub-expression or sub-graph REACHABILITY -- IR_CREATE's operand is
# a co-expression body with its own coret/cofail, a genuine separate graph root; IR_SUSPEND's
# is its value expression; IR_REPALT's is an alternation body entry whose re-entry is that
# construct's own semantics (MEASURED 2026-09-13: `every write(|1 \ 3)` matches icont, so it
# is green and is not to be "cured"). Only IR_MOVE_LABEL carried genuine CONTINUATIONS --
# the arms a gate jumps through -- which a port should have carried; Lon ordered it deleted
# (CEO-693/695) and it is the witness this gate is built from.
#
# ⭐ SO THE CEILING FALLS AND NEVER RISES. A NEW op that reaches control through its operand
# list is refused here at mint time, which is the only moment it is cheap -- reviewing the
# NAME would never have caught IR_MOVE_LABEL, and did not, for as long as it existed.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../../SCRIP/src/emitter/emit.cpp"
CEIL="${IR_OPERAND_CONTROL_PUSH_CEILING:-4}"
fail() { echo "⛔ $*"; exit 1; }
[ -f "$SRC" ] || { echo "⛔ REFUSE(2): no $SRC -- cannot measure"; exit 2; }
# The subject is the RPO successor macro: the walker's own definition of "what comes next".
BODY="$(awk '/^#define RPO_PUSH_SUCCS/,/[^\\]$/' "$SRC")"
[ -n "$BODY" ] || { echo "⛔ REFUSE(2): RPO_PUSH_SUCCS not found -- the macro moved or was renamed; this gate grades nothing until it is repointed"; exit 2; }
NAMES="$(printf '%s\n' "$BODY" | grep -oE '\(c\)->op == IR_[A-Z_]+ && \(c\)->n_operands' | grep -oE 'IR_[A-Z_]+' | sort -u)"
N="$(printf '%s\n' "$NAMES" | grep -c 'IR_' )"
echo "control-edge census: $N op(s) reach a successor through the OPERAND list, ceiling $CEIL"
printf '%s\n' "$NAMES" | sed 's/^/    /'
[ "$N" -le "$CEIL" ] || fail "GATE FAILED: $N > $CEIL -- a new IR op reaches control through its operand list. Control edges live on PORTS (α β γ ω). If this op is an instruction, it belongs in a template; if it is structure, wire it to a port. See CEO-695."
if printf '%s\n' "$NAMES" | grep -q '^IR_MOVE_LABEL$'; then
  echo "    ⚠ IR_MOVE_LABEL is still present -- Lon ordered it deleted (CEO-693); lower the ceiling to $((CEIL-1)) in the commit that removes it."
fi
echo "✅ GATE OK -- control-edge census $N/$CEIL, and the ceiling may only fall"
exit 0
