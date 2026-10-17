#!/usr/bin/env bash
# test_gate_raku_port_trace.sh -- THE PORT-TRACE INSTRUMENT for Raku (GOAL-TEST-SUITE-CONSISTENCY.md standard
# point 6; row test-suite-consistency-seven-languages-one-standard, hq_T 2026-09-04). Instantiates the shared body
# lib_port_trace.sh in FOUR TOKENS -- the whole point of extracting that body from the Prolog/SNOBOL4 pair. If you
# find yourself editing anything below the stanza, the change belongs in lib_port_trace.sh where all seven get it.
#   --to N     grade/cut rungs 0..N CUMULATIVELY.
#   --only N   grade/cut rung N ALONE -- the rung under construction, while the rungs BELOW it are still red.
#              Mutually exclusive with --to: naming BOTH REFUSES rc=2 rather than guessing.
#   --cut      rewrite corpus/tests/raku/ALL.trace from the live traces (the ONE way the ref changes).
# GRADED POPULATION: the `ladder` family of corpus/tests/raku/ALL.csv. Both modes.
# ⛔ THE TRACE REF IS A SELF-CONSISTENCY PIN, NOT AN ORACLE DIFF, AND THE DISTINCTION IS NOT COSMETIC: --cut writes
# ALL.trace from SCRIP's own traces, so a PASS proves the port sequence has not MOVED, never that it is RIGHT.
# ⭐ THE HONEST CELL FOR THIS LANGUAGE'S ORACLE DIFF IS "NOT BUILT YET", NEVER "IMPOSSIBLE". Rakudo has no Byrd-port trace to normalise; its `--tracing` output is a MoarVM-level instruction log, a different grain entirely, so an oracle diff here is a real design question and not a missing afternoon.
# `test_gate_icn_port_trace.sh` is the proof of shape: it normalises iconx's own \&trace onto the four Byrd ports
# and is strictly stronger than this pin. Until someone writes Raku's, this gate is the pinned instrument and
# says so; the ANSWER column is where Raku is graded against its real oracle today, and the rungs suite owns it.
# EXIT: 0 every witness matches in both modes; 1 a mismatch, a killswitch or perturbation failure; 2 REFUSED.
set -u
PORTTRACE_LANG=Raku; PORTTRACE_SUITE=raku; PORTTRACE_EXT=.raku; PORTTRACE_FAMILIES="ladder"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_port_trace.sh" || { echo "GATE UNPROVEN(2) [test_gate_raku_port_trace]: cannot source lib_port_trace.sh"; exit 2; }
port_trace_main "$@"
