#!/usr/bin/env bash
# test_prolog_ladder.sh -- THE CONSTRUCT-LADDER RUNNER, the landing gate of every Prolog rung of the rebuild
# (RULES.md § THE PROLOG REBUILD GATE clause 4; ARCH-PROLOG-BYRD-BOX-TRANSLATION.md § E; minted by hq_B 2026-09-02).
#   --to N     grade rungs 0..N CUMULATIVELY (default: every rung the rungs carries)
#   --only N   grade rung N ALONE -- the rung under construction, while the rungs below it are still red (ceo 2026-09-02: land rung 6 on --only 6
#              while --to 6 waits for rungs 2-5). Mutually exclusive with --to: a request that names both selectors REFUSES rc=2 rather than guessing.
#   --list     print the witnesses per rung and exit 0 without grading
# POPULATION: every origin `ladder__rungNN_<slug>` of corpus/tests/prolog/ALL.csv with NN <= N, materialized OUT of the rungs
# by origin through lib_rungs_extract.sh (RUNGS_DIR=corpus/tests/prolog, RUNGS_EXT=.pl) -- keyed on the CSV `origin`
# column, never on the entry name, which the builder renames (directive_82 today) and never on a filename glob.
# EACH WITNESS RUNS ALONE IN BOTH MODES:  m3 = scrip --run   ·   m4 = scrip --compile -o x.s + as --64 + gcc -no-pie + run
# (the port-trace gate's exact m4 recipe). Verdict per witness per mode: stdout byte-equal to the .ref AND rc equal to the
# declared rc (corpus/tests/prolog/ALL.wantrc, keyed on the entry NAME; default 0). A timeout is a FAIL(rc=124), never a hang.
# ⛔ XFAIL MARKERS ARE IGNORED HERE ON PURPOSE. The rungs board buckets a marked entry as XFAIL (reported, not gating, until
# rung 10); this runner is the gate for the rung that OWNS the witness, and a rung is landed only when its witnesses PASS.
# The marker's promotion (three places, lib_rungs_extract.sh's INTERIM PROMOTION PROTOCOL) is part of that rung's landing.
# THE TRACE ARM IS NOT HERE: test_gate_pl_port_trace.sh grades the ladder family's port traces against ALL.trace.
# PRINTS ITS DENOMINATOR. REFUSES rc=2 when it graded ZERO witnesses (no rungs, no ladder origins at or below --to N, or an
# extraction failure) -- a runner that cannot measure never prints the success shape (INSTRUMENT LAWS clause 2).
# FAILED ONCE, PASSED ONCE (INSTRUMENT LAWS, fifth batch): on the pre-cut tree SCRIP f4532dea / corpus <ladder landing>,
# `--to 2` is PASS 3/3 both modes and `--to 5` is FAIL (rung03_disjunction wrong output, two rung04 cut witnesses rc=139),
# and `S4E_HOME=/nonexistent` REFUSES rc=2 -- see FINDING-2026-09-02-hq_B-the-construct-ladder-runner-and-the-rung-0-5-witnesses.
# EXIT: 0 every graded witness PASS in both modes · 1 any FAIL · 2 REFUSED (cannot measure).
set -u
# ⭐ THE BODY IS SHARED: every language's ladder runner is this stanza over lib_ladder.sh, which carries the
# interface, the population rule, the grading and the printed shape ONCE for all seven (row
# test-suite-consistency-seven-languages-one-standard, hq_T 2026-09-03). Only the three tokens below vary.
LADDER_LANG=Prolog; LADDER_SUITE=prolog; LADDER_EXT=.pl
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ladder.sh" || { echo "REFUSE (rc=2): cannot source lib_ladder.sh"; exit 2; }
ladder_main "$@"
