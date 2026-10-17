#!/usr/bin/env bash
# test_gate_pl_no_value_stack.sh — NO-RESURRECT guard (Lon directive, 2026-05-31).
#
# The Prolog BB path is STACKLESS: a value lives in its box (per-activation slot g_resolve_env[slot],
# the ζ frame, or a sealed RO operand constant read by its consumer), NEVER on a global value stack.
# The value-stack push helpers rt_pl_atom_push and rt_pl_var_push were DELETED. This gate FAILS if any
# of them — or any new Prolog box reference to the g_vstack value-stack ops rt_push_*/rt_pop_*/
# vstack_push/vstack_pop — is resurrected. The trail (rt_pl_trail_*) is NOT banned: it is the legitimate
# binding-undo ledger (GOAL-PROLOG-BB: g_resolve_trail = KEEP). Comments are ignored (code only).
#
# Usage: bash ../harness/scripts/test_gate_pl_no_value_stack.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
fail=0

# strip_comments FILE — emit FILE with /* ... */ block comments and // line comments removed, so the
# greps below see CODE only (a comment mentioning g_vstack/rt_pl_var_push to explain the ban is fine).
strip_comments() { sed -E 's://.*$::' "$1" | perl -0777 -pe 's{/\*.*?\*/}{}gs'; }

# 1) The deleted push helpers must not be redefined or declared anywhere (code only).
banned_fns='rt_pl_atom_push|rt_pl_var_push|rt_pl_atom_pop|rt_pl_var_pop'
for f in $(grep -rlE "$banned_fns" src/ --include="*.c" --include="*.cpp" --include="*.h" 2>/dev/null); do
  h=$(strip_comments "$f" | grep -nE "$banned_fns")
  if [ -n "$h" ]; then
    echo "FAIL: a deleted Prolog value-stack push/pop helper was resurrected in $f:"
    echo "$h"
    fail=1
  fi
done

# 2) No Prolog box template may touch the g_vstack value-stack ops (code only).
pl_boxes="src/templates/bb/bb_arith.cpp \
          src/templates/bb/bb_cut.cpp \
          src/templates/bb/bb_succeed.cpp \
          src/templates/bb/bb_fail.cpp"
vstack_ops='rt_push_int|rt_push_str|rt_pop_|vstack_push|vstack_pop|g_vstack'
for f in $pl_boxes; do
  [ -f "$f" ] || continue
  h=$(strip_comments "$f" | grep -nE "$vstack_ops")
  if [ -n "$h" ]; then
    echo "FAIL: Prolog box $f references a g_vstack value-stack op (must be stackless):"
    echo "$h"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "PASS: no resurrected Prolog value-stack push/pop; all Prolog boxes stackless."
fi
exit $fail
