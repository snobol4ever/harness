#!/usr/bin/env bash
# util_cc_slot.sh <compiler> <args>... -- ONE POOL OF COMPILE SLOTS FOR THE WHOLE BOX (Lon 2026-10-22, in-chat, verbatim: "You are meant
# to fix the load not hurt it" · "don't flag things, fix things."; R-1894). Every seat's `make -j8` used to start its own eight compilers, so
# eleven seats building at once ran far past the sixteen cores. The SCRIP Makefile runs every gcc and g++ through this wrapper: it takes one of
# S4E_CC_SLOTS (default 8, half the box) slot locks under /tmp/s4e-cc-slots, waiting when all are held, and execs the compiler with the lock
# held on fd 9 for the compiler's whole life (flock is released by the kernel when the process exits, so a killed compile frees its slot).
# A free slot is taken at once; with none free it rescans every slot twice a second and never queues on one (a holder that lives long would pin the waiter; coo 2026-10-30, R-2054). Not a gate and no record: it only bounds how many compilers run.
# SINCE 2026-10-31 (the cto, ARCH-SHARED-DEVELOPMENT 4.3, R-2041 step 3) THE RULE LIVES IN lib_slots.sh: a seat file first (cap S4E_CC_SEAT_CAP, default 4), then a pool slot.
# A QUERY COMPILES NOTHING AND TAKES NO TOKEN (the chairman 2026-11-18; MEASURED 12:45 CST from SLOT_WAITS.tsv: 544 waits of "gcc --version" since 06:00 CST, 14565 s in all, 67 of them a
# minute or more, the longest 323 s, the grader's patch drain standing at the door inside util_build_cache.sh, which asks the compiler its version for the cache key): a compiler asked only
# for its version, its machine, its help or a path it prints runs at once, outside the door.
case "$#:${2:-}" in 2:--version|2:-dumpversion|2:-dumpfullversion|2:-dumpmachine|2:--help|2:-v|2:-print-*) exec "$@" ;; esac
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_slots.sh"
# THE COSTS LEDGER (the weighted door, step 1): the run is waited by util_cost_run.py, which appends one line of what the kernel counted for it to COSTS.tsv (S4E_COSTS=off, or no python3, execs the command bare as before); python3 -I -S, since the site import alone is 20 M instructions of the 46 M the wrapper costs.
_s4e_cost_exec() { _cc="$1"; shift; _cr="$(dirname "$(readlink -f "$0")")/util_cost_run.py"; if [ "${S4E_COSTS:-}" != off ] && [ -f "$_cr" ] && command -v python3 >/dev/null 2>&1; then exec python3 -I -S "$_cr" --class "$_cc" --key auto -- "$@"; fi; exec "$@"; }
s4e_slot_hold cc; _rc=$?; [ "$_rc" = 2 ] && exit 2; [ "$_rc" = 0 ] || _s4e_cost_exec cc "$@"
s4e_slot_note cc "$S4E_SLOT_T0" "$@"
_s4e_cost_exec cc "$@"
