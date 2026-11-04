#!/usr/bin/env bash
# util_cc_slot.sh <compiler> <args>... -- ONE POOL OF COMPILE SLOTS FOR THE WHOLE BOX (Lon 2026-10-22, in-chat to the ceo, verbatim: "You are meant
# to fix the load not hurt it" · "don't flag things, fix things."; ceo CEO-1894). Every seat's `make -j8` used to start its own eight compilers, so
# eleven seats building at once ran far past the sixteen cores. The SCRIP Makefile runs every gcc and g++ through this wrapper: it takes one of
# S4E_CC_SLOTS (default 8, half the box) slot locks under /tmp/s4e-cc-slots, waiting when all are held, and execs the compiler with the lock
# held on fd 9 for the compiler's whole life (flock is released by the kernel when the process exits, so a killed compile frees its slot).
# A free slot is taken at once; with none free it rescans every slot twice a second and never queues on one (a holder that lives long would pin the waiter; coo 2026-10-30, CEO-2054). Not a gate and no record: it only bounds how many compilers run.
# SINCE 2026-10-31 (the cto, ARCH-SHARED-DEVELOPMENT 4.3, CEO-2041 step 3) THE RULE LIVES IN lib_slots.sh: a seat file first (cap S4E_CC_SEAT_CAP, default 4), then a pool slot.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_slots.sh"
s4e_slot_hold cc; _rc=$?; [ "$_rc" = 2 ] && exit 2; [ "$_rc" = 0 ] || exec "$@"
s4e_slot_note cc "$S4E_SLOT_T0" "$@"
exec "$@"
