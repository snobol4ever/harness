#!/usr/bin/env bash
# test_gate_sno_port_trace.sh -- THE PORT-TRACE INSTRUMENT for SNOBOL4 (GOAL-TEST-SUITE-CONSISTENCY.md standard
# point 6; row test-suite-consistency-seven-languages-one-standard, hq_T 2026-09-03). The SECOND instance of this
# gate, minted deliberately so lib_port_trace.sh could be extracted from a PAIR rather than guessed from the one
# Prolog example -- exactly how lib_ladder.sh was extracted. The two bodies differed in FOUR tokens, which are the
# four set below; everything else is shared and lives in lib_port_trace.sh.
#   --to N     grade/cut rungs 0..N CUMULATIVELY.
#   --only N   grade/cut rung N ALONE -- the rung under construction, while the rungs BELOW it are still red.
#              Mutually exclusive with --to: naming BOTH REFUSES rc=2 rather than guessing.
#   --cut      rewrite corpus/tests/snobol4/ALL.trace from the live traces (the ONE way the ref changes).
# GRADED POPULATION: the `ladder` family of corpus/tests/snobol4/ALL.csv -- the rungs 0-9 construct ladder landed
# by hq_T 2026-09-03, whose refs are oracle-cut from `sbl -bf`. Both modes.
# ⛔ THE TRACE REF IS A SELF-CONSISTENCY PIN, NOT AN ORACLE DIFF, AND THE DISTINCTION IS NOT COSMETIC: --cut writes
# ALL.trace from SCRIP's own traces, so a PASS proves the port sequence has not MOVED, never that it is RIGHT.
# ⭐ AN ORACLE DIFF IS POSSIBLE HERE AND IS SIMPLY NOT BUILT YET -- do not record it as impossible. SPITBOL's
# &TRACE emits variable/label/function events in its own format rather than a Byrd four-port sequence, so it
# needs a normalisation layer; `test_gate_icn_port_trace.sh` builds exactly that layer for iconx's &trace and is
# the proof of shape. Until someone writes SNOBOL4's, this gate is the pinned instrument and says so. The ANSWER
# column is where SNOBOL4 is graded against the real oracle today, and the rungs suite owns that.
# EXIT: 0 every witness matches in both modes; 1 a mismatch, a killswitch or perturbation failure; 2 REFUSED.
set -u
PORTTRACE_LANG=SNOBOL4; PORTTRACE_SUITE=snobol4; PORTTRACE_EXT=.sno; PORTTRACE_FAMILIES="ladder"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_port_trace.sh" || { echo "GATE UNPROVEN(2) [test_gate_sno_port_trace]: cannot source lib_port_trace.sh"; exit 2; }
port_trace_main "$@"
