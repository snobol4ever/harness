#!/usr/bin/env bash
# ../harness/scripts/test_gate_emit_fields_read_by_a_template_have_a_writer.sh — cfo, on hq_B's finding under CEO-534.
#
# WHAT IT GATES.  A FIELD WITH A READER AND NO WRITER IS INVISIBLE.  `g_emit` (emit.h) is the one
# channel from the emitter's per-node prepare into the x86 templates: the drive in emit.cpp WRITES
# `g_emit.op_*`, and a template READS the same field as `_.op_*`.  When a landing deletes the write
# and leaves the read, NOTHING SAYS SO: it compiles clean, the field still greps as present-and-used,
# and the template's own ternary default supplies a plausible answer forever.
#
# ⛔ THE MEASURED CASE THIS GATE EXISTS FOR (hq_B's bisect, 2026-09-10).  The cfo's cset-bit-table
# PERF landing `539af6946` also deleted three lines that were not perf, among them the assignment of
# the activation's procedure name into `g_emit.op_activate_proc`.  `op_activate_proc` stayed DECLARED
# in emit.h and READ by bb_activate, and was WRITTEN BY NOBODY.  Every co-expression activation trace
# event then fell to the template's `main` default: 67 of arizona transmit.std's 104 lines named
# `main` where the oracle names `output`, `word` and `reader`, and 28 of those also carried the
# enclosing `while` line instead of the activation site's own.  Nothing failed to build.  The cure was
# `4257407de`; this gate is the cheap census that would have caught it AT LANDING TIME rather than
# after a bisect, and it is a grep, not a run: no build, no oracle, no corpus.
#
# ⭐ WHY A PINNED FLOOR AND NOT ZERO.  Three fields are read with no writer TODAY and are not this
# defect: they are dead weight from templates the driver no longer reaches.  Deleting them is a
# separate cleanup with its own control arms, so they are named here and the census may not GROW
# past them.  Lower the floor in the commit that removes one; never raise it.
#
#   op_bounded     — read once (a template arm gated on it, so the arm never fires)
#   op_kind        — read once; the only assignment anywhere is emit_per_kind_audit.c setting it NULL
#   op_parts_lbl   — read by bb_idx_get (a template bb_templates.h declares and emit.cpp never calls)
#                    and by three gvar-arith arms whose IF therefore never fires
#
# ⭐ FLOOR 3 -> 0 (cto 2026-09-23, CEO-1169, THE DELETION OF THE DEAD TEMPLATES): all three readers above
#   lived in templates with NO CALLER anywhere in src/ -- bb_idx_get.cpp, bb_binop_gvar_arith.cpp and
#   bb_binop_gvar_arith_slot.cpp -- and they went with the other fifteen dead definition files and the
#   fifteen header-only prototypes in that landing (a caller census over every bb_* name declared in
#   bb_templates.h, definition and header excluded; IR kinds absent from IR.h, the emitter's switch and every
#   lowerer).  The gate read "0 field(s) read with no writer, floor 3 -- FELL by 3" on that tree, which is
#   the one direction this floor may move.  Nothing else may lower it silently: a NEW dead reader is RED.
#
# ⛔ HOW TO CONTROL-ARM IT, AND THE WRONG WAY THAT LOOKS RIGHT.  Remove every writer of a field and it
# must go RED naming that field.  ⛔ Rename the write to a name that SHARES ITS PREFIX and the census
# still sees it: the pattern takes the longest run of [a-z0-9_], so `g_emit.op_activate_procZZ` yields
# the token `op_activate_proc` and the gate stays green.  That is how this gate first "passed" its own
# control arm; rename to something disjoint (`g_emit.op_zzdead`) instead.  Measured green-then-red on
# `op_activate_proc` 2026-09-10 before wiring.
#
# ⛔ WHAT IT CANNOT SEE.  A field written on ONE drive path and read on ANOTHER is still invisible on
# the second path; this gate only proves that SOMEBODY writes it somewhere.  It is a floor under the
# whole class, not a proof for any one node.
set -u
export LC_ALL=C   # ⛔ comm compares byte-wise; sort under a UTF-8 locale ignores underscores, so an
                  # unsorted-by-comm's-rules list makes the census silently WRONG (measured: the control
                  # arm below stayed green with every writer of op_activate_proc removed until this line).
cd "$(dirname "$0")/../../SCRIP" || exit 2
[ -f src/emitter/emit.h ] || { echo "⛔ GATE REFUSES(2): src/emitter/emit.h missing"; exit 2; }
[ -d src/templates/bb ]   || { echo "⛔ GATE REFUSES(2): src/templates/bb missing"; exit 2; }

FLOOR=0
PINNED="op_bounded op_kind op_parts_lbl"

readers=$(grep -rhoE '_\.op_[a-z0-9_]+' src/templates/bb/*.cpp src/templates/x86/*.h 2>/dev/null | sed 's/^_\.//' | sort -u)
writers=$(grep -rhoE 'g_emit\.op_[a-z0-9_]+' src/emitter/*.cpp src/emitter/*.c 2>/dev/null | sed 's/^g_emit\.//' | sort -u)
[ -n "$readers" ] || { echo "⛔ GATE REFUSES(2): no template reads found -- the census pattern no longer matches the source"; exit 2; }
[ -n "$writers" ] || { echo "⛔ GATE REFUSES(2): no emitter writes found -- the census pattern no longer matches the source"; exit 2; }

orphans=$(comm -23 <(printf '%s\n' "$readers") <(printf '%s\n' "$writers"))
n=$(printf '%s\n' "$orphans" | grep -c . || true)

echo "emit-field census: $(printf '%s\n' "$readers" | grep -c .) field(s) read by a template, $(printf '%s\n' "$writers" | grep -c .) written by the emitter"
rc=0
if [ "$n" -gt "$FLOOR" ]; then
    echo "  ⛔ $n field(s) read with NO writer, floor $FLOOR -- GREW by $((n - FLOOR))"
    for f in $orphans; do
        case " $PINNED " in *" $f "*) continue;; esac
        echo "     NEW: $f  -- read by: $(grep -rl "_\.$f" src/templates/bb/*.cpp 2>/dev/null | xargs -r -n1 basename | tr '\n' ' ')"
        echo "          A landing deleted its write in the emitter, or it was never wired. The template's default is answering instead."
    done
    rc=1
elif [ "$n" -lt "$FLOOR" ]; then
    echo "  ⭐ $n field(s) read with no writer, floor $FLOOR -- FELL by $((FLOOR - n)); lower FLOOR to $n in this commit"
    rc=1
else
    echo "  ok    $n field(s) read with no writer, at the pinned floor: $(printf '%s' "$orphans" | tr '\n' ' ')"
fi
[ $rc -eq 0 ] && echo "✅ GATE PASS [emit_fields_read_by_a_template_have_a_writer]: every g_emit field a template reads is written by the emitter, but for the $FLOOR pinned dead ones" \
              || echo "⛔ GATE FAIL [emit_fields_read_by_a_template_have_a_writer]: the census moved -- see above"
exit $rc
