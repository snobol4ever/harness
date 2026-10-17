#!/usr/bin/env bash
# test_snocone_ladder.sh -- THE CONSTRUCT-LADDER RUNNER for Snocone (GOAL-TEST-SUITE-CONSISTENCY.md standard point 1;
# row snocone-construct-ladder-and-parser-fixtures, seat12). Minted by hq_T 2026-09-03 from the ONE shared body lib_ladder.sh, which
# is test_prolog_ladder.sh's and test_raku_ladder.sh's body extracted once for all seven languages.
#   --to N     grade rungs 0..N CUMULATIVELY (default: every rung the rungs carries)
#   --only N   grade rung N ALONE -- the rung under construction, while the rungs below it are still red.
#              Mutually exclusive with --to: a request naming both REFUSES rc=2 rather than guessing.
#   --list     print the witnesses per rung and exit 0 without grading
# POPULATION: every origin `ladder__rungNN_<slug>` of corpus/tests/snocone/ALL.csv with NN <= N, materialized OUT of
# the rungs by origin through lib_rungs_extract.sh (RUNGS_DIR=corpus/tests/snocone, RUNGS_EXT=.sc) -- keyed on
# the CSV `origin` column, never on the entry name and never on a filename glob.
# EACH WITNESS RUNS ALONE IN BOTH MODES:  m3 = scrip --run  ·  m4 = scrip --compile -o x.s + as --64 + gcc -no-pie + run
# Verdict per witness per mode: stdout byte-equal to the .ref AND rc equal to the declared rc (ALL.wantrc, keyed
# on the entry NAME; default 0). A timeout is a FAIL(rc=124), never a hang.
# ⭐ THE ORACLE THAT MUST CUT THIS LANGUAGE'S REFS: the SPITBOL oracle `/home/resources/x64/bin/sbl` with `-bf` (`sbl_correctness_bin()`), same authority as
# SNOBOL4 -- SCRIP follows SPITBOL for both and is case-sensitive.
# ⛔ STATE OF THIS LADDER RIGHT NOW (hq_T 2026-09-03, measured): corpus/tests/snocone/ALL.csv carries ZERO
# `ladder__rung*` origins, so this runner correctly REFUSES rc=2 -- it cannot measure, and a runner that cannot
# measure never prints the success shape. That refusal is the instrument working, not a break. Building the
# rungs is row snocone-construct-ladder-and-parser-fixtures (seat12); the runner is ready for them now.
# EXIT: 0 every graded witness PASS in both modes · 1 any FAIL · 2 REFUSED (cannot measure).
set -u
# ⭐ THE BODY IS SHARED: every language's ladder runner is this stanza over lib_ladder.sh, which carries the
# interface, the population rule, the grading and the printed shape ONCE for all seven (row
# test-suite-consistency-seven-languages-one-standard, hq_T 2026-09-03). Only the three tokens below vary.
LADDER_LANG=Snocone; LADDER_SUITE=snocone; LADDER_EXT=.sc
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ladder.sh" || { echo "REFUSE (rc=2): cannot source lib_ladder.sh"; exit 2; }
ladder_main "$@"
