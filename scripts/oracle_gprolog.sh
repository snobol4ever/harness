#!/usr/bin/env bash
# oracle_gprolog.sh -- THE GNU PROLOG ORACLE, RUN WITH ITS OWN TOOLS FIRST ON PATH (ceo CEO-1598, 2026-10-10; the coo's measured fact 1).
# 1.6.0's gprolog compiles a consulted file by running `pl2wam` FROM PATH; with /usr/bin first that is 1.4.5's pl2wam, which rejects
# the 1.6.0 option ("unknown option --include") and every --consult-file run fails. So the accessor gprolog_bin() names THIS wrapper,
# which puts the oracle's bin directory first and execs the real binary. Nothing else here: no filter, no flag, no banner edit --
# the oracle's output reaches the caller as the oracle prints it.
D="/home/resources/gprolog-mon/pristine/gprolog-1.6.0/bin"
[ -x "$D/gprolog" ] || { printf '⛔ THE GNU-PROLOG ORACLE IS MISSING: %s/gprolog (ORACLES.md, ORACLE SWAP 2026-10-10)\n' "$D" >&2; exit 2; }
PATH="$D:$PATH" exec "$D/gprolog" "$@"
