#!/usr/bin/env bash
# test_gate_the_tiny_open_protocol_and_its_glue_record_agree.sh -- TWO FILES HOLD ONE CONTRACT AND NOTHING BOUND THEM.
#
# ⛔⭐ THE DEFECT, MEASURED BY THE ceo AT THE COST OF TWO FAILED CONVERSION ATTEMPTS (CEO-1089, cured by the cto
# 2026-09-21 as spine).  rt_call_open_by_name returns a two-word {entry, protocol}; the protocol's low byte is `how`.
# bb_glue_enter_c2bb performs the jump, and its how==2 arm (the TINY/alpha record) built a FIXED 48-byte record whose
# ARGUMENT COUNT WAS THE LITERAL ZERO and which never copied g_call_args.  rt_tiny_record_enter's own asm shim -- the
# other way into the same target -- sizes its record FROM nargs, copies every argument out of g_call_args, and writes
# the real count.  So the two roads into one callee disagreed about the record's shape.
# ⛔ IT PRESENTED AS A WRONG ANSWER, NOT A CRASH: a target opened onto how=2 with arguments entered WITH NO ARGUMENTS and
# read unbound parameters (the ceo measured APPLY(ZFN,41) returning 1 instead of 42).  The 2026-09-21 cure made the open
# take the tiny road ONLY at nargs<=0 and sent an argument-bearing call down the NAMED road.
# ⛔ AND THAT WORKAROUND CRASHED A SNOCONE FUNCTION (the cto, 2026-10-03, row snocone-apply-of-a-snocone-defined-function-
# crashes-scrip): for a Snocone function p->fn IS its tiny alpha, so APPLY('f', 2) took the named road (how=1, the glue
# jumps with rcx = a continuation label) into a prologue that reads its call record through rcx -- a GP fault in the slab.
# ⭐ THE BETTER CURE, LANDED THEN: the glue's how==2 arm hands its record (gamma and omega at [8] and [16]) to the
# trampoline rt_tiny_glue_enter (src/runtime/rt/rt_asm_helpers.S, jump-entered, box to asm to box), which takes the count
# from the how word (rt_c2bb_word(p, afn, 2, nargs) puts it in bits 8-39), builds the callee's record below the glue's --
# count, its own gamma/omega stubs, one offset per argument -- copies every argument out of g_call_args beside it, jumps to
# the alpha, and on return drops that frame and jumps on to the glue's continuation.  The nargs guard is LIFTED.
# THIS GATE holds the contract across the three files: the glue reaches the trampoline, the trampoline sizes from the count
# and copies g_call_args, and the open no longer guards how=2 on nargs -- or, if the glue ever goes back to a fixed
# zero-count record that copies nothing, the guard must return.  FAIL_ONCE=1 pretends the guard is still there.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
RT="src/runtime/rt/rt.c"; GLUE="src/templates/bb/bb_glue_flat.cpp"; ASM="src/runtime/rt/rt_asm_helpers.S"
[ -f "$RT" ] && [ -f "$GLUE" ] && [ -f "$ASM" ] || { echo "REFUSE(2): a source file this gate grades is missing"; exit 2; }

glue_body="$(sed -n '/^std::string bb_glue_enter_c2bb/,/^}/p' "$GLUE")"
[ -n "$glue_body" ] || { echo "REFUSE(2): bb_glue_enter_c2bb not found in $GLUE -- the gate cannot grade what it cannot read"; exit 2; }
tramp="$(sed -n '/^rt_tiny_glue_enter:/,/^ *\.size *rt_tiny_glue_enter/p' "$ASM")"

rc=0
reaches=0; printf '%s\n' "$glue_body" | grep -q 'rt_tiny_glue_enter' && reaches=1
sizes=0; [ -n "$tramp" ] && printf '%s\n' "$tramp" | grep -q 'shrq *\$8, *%rsi' && sizes=1
copies=0; [ -n "$tramp" ] && printf '%s\n' "$tramp" | grep -q 'g_call_args' && copies=1
carries_args=0; [ $reaches = 1 ] && [ $sizes = 1 ] && [ $copies = 1 ] && carries_args=1
echo "arm 1: the glue's how==2 arm reaches rt_tiny_glue_enter? $( [ $reaches = 1 ] && echo YES || echo NO )"
echo "arm 2: rt_tiny_glue_enter sizes the record from the how word's count and copies g_call_args? $( [ $sizes = 1 ] && [ $copies = 1 ] && echo YES || echo NO )"
guarded=0
grep -q 'if (p->dyn_scope && nargs <= 0) {.*rt_c2bb_word(p, (long)(uintptr_t)afn, 2, 0)' "$RT" && guarded=1
if [ "${FAIL_ONCE:-0}" = "1" ]; then guarded=1; echo "FAIL_ONCE: pretending the nargs<=0 guard is still in rt_call_open_by_name -- the gate must red"; fi
echo "arm 3: rt_call_open_by_name guards its how=2 return on nargs? $( [ $guarded = 1 ] && echo YES || echo NO )"

if [ $carries_args = 1 ]; then
  if [ $guarded = 1 ]; then
    echo "⛔ GATE FAILED: the glue's how==2 road carries arguments through rt_tiny_glue_enter, so a nargs<=0 guard in rt_call_open_by_name is STALE: it sends an argument-bearing call to a tiny alpha down the named road, which jumps with no call record (the Snocone APPLY crash). Lift the guard."
    rc=1
  else
    echo "✅ the three sites agree: the glue reaches the trampoline, the trampoline carries the real count and every argument, and the open is free to use the tiny road"
  fi
else
  if [ $guarded = 0 ]; then
    echo "⛔ GATE FAILED: the glue's how==2 road no longer carries arguments (no trampoline, or one that neither sizes from the count nor copies g_call_args), yet rt_call_open_by_name returns how=2 for a call WITH arguments: that target enters with none and returns a wrong answer."
    rc=1
  else
    echo "✅ the sites agree on the zero-argument record: the open takes the tiny road only at nargs<=0"
  fi
fi
exit $rc
