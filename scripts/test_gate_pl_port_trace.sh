#!/usr/bin/env bash
# test_gate_pl_port_trace.sh -- BX-0 THE PORT-TRACE INSTRUMENT for PROLOG (ARCH-PROLOG-BYRD-BOX-TRANSLATION.md § D /
# § E rung 1; hq_P 2026-09-02). ⭐ THE BODY IS NOW SHARED: this file was the ONLY port-trace gate that existed, and
# hq_T extracted its body to lib_port_trace.sh once a SECOND instance (test_gate_sno_port_trace.sh) existed to diff
# it against -- the same discipline that produced lib_ladder.sh, and for the same reason: with one instance the
# seams are a guess. Only the four tokens below vary between languages (row
# test-suite-consistency-seven-languages-one-standard, GOAL-TEST-SUITE-CONSISTENCY.md standard point 6).
#   --to N     grade/cut rungs 0..N CUMULATIVELY.
#   --only N   grade/cut rung N ALONE -- the rung under construction, while the rungs BELOW it are still red.
#              Mutually exclusive with --to: naming BOTH REFUSES rc=2 rather than guessing.
#   --cut      rewrite corpus/tests/prolog/ALL.trace from the live traces (the ONE way the ref changes).
# GRADED POPULATION: every origin of the FAMILIES list (default `probe_plz ladder`: the PZ-0 witnesses and the
# construct-ladder witnesses of ARCH-PROLOG-BYRD-BOX-TRANSLATION.md § E, hq_B 2026-09-02) of
# corpus/tests/prolog/ALL.csv, both modes. The per-witness checks, the normalisation, the prefix-ref format and
# the printed shape all live in lib_port_trace.sh -- read that file's header, it is the contract.
# ⛔ THE REF IS A SELF-CONSISTENCY PIN, NOT AN ORACLE DIFF: --cut writes it from SCRIP's own traces, so a PASS
# proves the port sequence has not MOVED, never that it is RIGHT. Prolog's trace/0 emits goal events in its own
# format, not a Byrd four-port sequence over our box graph, so no line-for-line oracle diff exists to take.
# Say "pinned" in any receipt quoting this gate (ceo CEO-172).
# EXIT: 0 every witness matches in both modes; 1 a mismatch, a killswitch or perturbation failure; 2 REFUSED.
set -u
PORTTRACE_LANG=Prolog; PORTTRACE_SUITE=prolog; PORTTRACE_EXT=.pl; PORTTRACE_FAMILIES="probe_plz ladder"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_port_trace.sh" || { echo "GATE UNPROVEN(2) [test_gate_pl_port_trace]: cannot source lib_port_trace.sh"; exit 2; }
port_trace_main "$@"
