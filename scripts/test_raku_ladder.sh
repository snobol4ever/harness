#!/usr/bin/env bash
# test_raku_ladder.sh -- THE CONSTRUCT-LADDER RUNNER for Raku (GOAL-TEST-SUITE-CONSISTENCY.md, row
# raku-construct-ladder-from-rung-0; shape copied from test_prolog_ladder.sh, minted by hq_B 2026-09-02).
#   --to N     grade rungs 0..N CUMULATIVELY (default: every rung the rungs carries)
#   --only N   grade rung N ALONE -- the rung under construction, while the rungs below it are still red.
#              Mutually exclusive with --to: a request naming both REFUSES rc=2 rather than guessing.
#   --list     print the witnesses per rung and exit 0 without grading
# POPULATION: every origin `ladder__rungNN_<slug>` of corpus/tests/raku/ALL.csv with NN <= N, materialized
# OUT of the rungs by origin through lib_rungs_extract.sh (RUNGS_DIR=corpus/tests/raku, RUNGS_EXT=.raku)
# -- keyed on the CSV `origin` column, never on the entry name or a filename glob.
# EACH WITNESS RUNS ALONE IN BOTH MODES:  m3 = scrip --run   ·   m4 = scrip --compile -o x.s + as --64 + gcc -no-pie + run
# Verdict per witness per mode: stdout byte-equal to the .ref AND rc equal to the declared rc (ALL.wantrc,
# keyed on the entry NAME; default 0, and the file need not exist -- every rung 0-9 witness here exits 0).
# A timeout is a FAIL(rc=124), never a hang.
# ⭐ REFS ARE ORACLE-CUT, NOT HAND-AUTHORED: every .ref line for a ladder witness is the literal captured
# stdout of the real Raku (Rakudo) oracle on that exact source, via `rakudo_bin()` in lib_oracle_flags.sh
# (prefers /home/resources/rakudo-local/bin/raku, falls back to /usr/bin/raku) -- never a hand-typed guess.
# This runner does not re-invoke Rakudo at grading time (same reason test_prolog_ladder.sh does not re-invoke
# swipl/gprolog per run): the .ref is the recorded oracle answer, cut once, and the runner's only job is
# diffing SCRIP against it. Re-cut a rung's .ref only when its witness source changes.
# ⛔ XFAIL MARKERS ARE IGNORED HERE ON PURPOSE, same as the Prolog runner: this is the gate for the rung
# that OWNS the witness, and a rung is landed only when its witnesses PASS.
# PRINTS ITS DENOMINATOR. REFUSES rc=2 when it graded ZERO witnesses (no rungs, no ladder origins at or
# below --to N, or an extraction failure) -- a runner that cannot measure never prints the success shape.
# FAILED ONCE, PASSED ONCE (INSTRUMENT LAWS): rungs 0-9 (10 witnesses, one per rung) were built and verified
# against Rakudo 2026.x (rakudo-local) 2026-09-03 by seat11 -- `--to 5` and `--to 9` both PASS 20/20 and
# 20/20 witness x mode; before the corpus fixtures existed, `--to 5` correctly REFUSED rc=2 (no ladder
# origins yet), and a deliberately-broken witness (wrong .ref line) correctly FAILed -- see the task's LEDGER.
# EXIT: 0 every graded witness PASS in both modes · 1 any FAIL · 2 REFUSED (cannot measure).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
set -u
# ⭐ THE BODY IS SHARED: every language's ladder runner is this stanza over lib_ladder.sh, which carries the
# interface, the population rule, the grading and the printed shape ONCE for all seven (row
# test-suite-consistency-seven-languages-one-standard, hq_T 2026-09-03). Only the three tokens below vary.
LADDER_LANG=Raku; LADDER_SUITE=raku; LADDER_EXT=.raku
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ladder.sh" || { echo "REFUSE (rc=2): cannot source lib_ladder.sh"; exit 2; }
ladder_main "$@"
