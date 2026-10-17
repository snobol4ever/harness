#!/usr/bin/env bash
# oracle_gplc.sh -- THE GNU PROLOG COMPILER OF THE ORACLE, RUN WITH ITS OWN TOOLS FIRST ON PATH (ceo CEO-1598, 2026-10-10).
# The twin of oracle_gprolog.sh: gplc drives pl2wam, wam2ma and ma2asm, and the 1.6.0 set must be the one it finds. The accessor
# gplc_bin() names this wrapper. Nothing else here.
D="/home/resources/gprolog-mon/pristine/gprolog-1.6.0/bin"
[ -x "$D/gplc" ] || { printf '⛔ THE GNU-PROLOG COMPILER gplc IS MISSING: %s/gplc (ORACLES.md, ORACLE SWAP 2026-10-10)\n' "$D" >&2; exit 2; }
PATH="$D:$PATH" exec "$D/gplc" "$@"
