#!/usr/bin/env bash
# util_run_slot.sh <command> <args>... -- AN AD-HOC RUN TAKES ONE OF THE BOX'S RUN SLOTS (Lon 2026-10-30, in-chat to the ceo, verbatim: "let's get
# the machine here not to be overloaded currently." · "Yes, do try your suggestions to fix the load problems."; ceo CEO-2033). Measured at 09:4x
# CDT: load 27 on 16 cores while the box's pools sat nearly idle (1 of 8 compile slots, 2 of 8 run slots), because the heavy runs bypassed them:
# a seat's own before-and-after binaries, a second scrip run started by hand, a compile-all sweep. The harness takes a run slot for every child it
# starts (corpus_suite_harness.py:_run_slot, CEO-1894); this wrapper takes the SAME slot locks under /tmp/s4e-run-slots for a run a seat starts
# itself, so hand runs and harness runs share one pool of S4E_RUN_SLOTS (default 8). It waits when every slot is held (rescanning every slot twice a second, never queued on one: a serial script holding a slot for hours pinned a waiter 17 minutes, 10-30) and execs the command with
# the lock on fd 8 for the command's whole life (the kernel frees it when the process exits, so a killed run frees its slot). A run already under
# a harness slot (S4E_RUN_SLOT_HELD set) takes no second one.
#   bash ../harness/scripts/util_run_slot.sh ./scrip prog.sno < /dev/null
#   bash ../harness/scripts/util_run_slot.sh ./old.bin -d64m
[ "$#" -gt 0 ] || { echo "usage: util_run_slot.sh <command> <args>..." >&2; exit 2; }
[ -n "${S4E_RUN_SLOT_HELD:-}" ] && exec "$@"
# SINCE 2026-10-31 (the cto, ARCH-SHARED-DEVELOPMENT 4.3, CEO-2041 step 3) THE RULE LIVES IN lib_slots.sh: a seat file first (cap S4E_RUN_SEAT_CAP, default 3), then a pool slot;
# S4E_CLASS=grader takes no seat file and may take any slot, every other taker leaves the top S4E_RUN_GRADER_RESERVED (2) slots to the grader.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_slots.sh"
s4e_slot_hold run; _rc=$?; [ "$_rc" = 2 ] && exit 2; [ "$_rc" = 0 ] || exec "$@"
s4e_slot_note run "$S4E_SLOT_T0" "$@"
exec "$@"
