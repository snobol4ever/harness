#!/usr/bin/env bash
# test_pascal_ladder.sh -- THE CONSTRUCT-LADDER RUNNER for Pascal (GOAL-TEST-SUITE-CONSISTENCY.md, row
# pascal-smoke-floor-gate-and-construct-ladder-from-rung-0; shape copied from test_prolog_ladder.sh via
# test_raku_ladder.sh, minted by hq_B 2026-09-02).
#   --to N     grade rungs 0..N CUMULATIVELY (default: every rung the rungs carries)
#   --only N   grade rung N ALONE -- the rung under construction, while the rungs below it are still red.
#              Mutually exclusive with --to: a request naming both REFUSES rc=2 rather than guessing.
#   --list     print the witnesses per rung and exit 0 without grading
# POPULATION: every origin `ladder__rungNN_<slug>` of corpus/tests/pascal/ALL.csv with NN <= N, materialized
# OUT of the rungs by origin through lib_rungs_extract.sh (RUNGS_DIR=corpus/tests/pascal, RUNGS_EXT=.pas)
# -- keyed on the CSV `origin` column, never on the entry name or a filename glob.
# EACH WITNESS RUNS ALONE IN BOTH MODES:  m3 = scrip --run   ·   m4 = scrip --compile -o x.s + as --64 + gcc -no-pie + run
# Verdict per witness per mode: stdout byte-equal to the .ref AND rc equal to the declared rc (ALL.wantrc,
# keyed on the entry NAME; default 0, and the file need not exist -- every rung 0-9 witness here exits 0).
# A timeout is a FAIL(rc=124), never a hang.
# ⭐ REFS ARE ORACLE-CUT, NOT HAND-AUTHORED: every .ref line for a ladder witness is the literal captured
# stdout of the real `fpc -Miso` oracle (FPC 3.2.2, ISO 7185 mode -- GOAL-CEO CEO-33) on that exact source.
# rung09_strings uses `packed array[1..N] of char` (ISO 7185's actual string mechanism), never Delphi's
# `string` type, which -Miso itself rejects -- confirmed directly (`Error: Identifier not found "string"`)
# before writing the witness, not assumed. This runner does not re-invoke fpc at grading time (same reason
# test_prolog_ladder.sh does not re-invoke swipl/gprolog per run): the .ref is the recorded oracle answer,
# cut once, and the runner's only job is diffing SCRIP against it. Re-cut a rung's .ref only when its
# witness source changes.
# ⛔ XFAIL MARKERS ARE IGNORED HERE ON PURPOSE, same as the Prolog/Raku runners: this is the gate for the
# rung that OWNS the witness, and a rung is landed only when its witnesses PASS.
# PRINTS ITS DENOMINATOR. REFUSES rc=2 when it graded ZERO witnesses (no rungs, no ladder origins at or
# below --to N, or an extraction failure) -- a runner that cannot measure never prints the success shape.
# FAILED ONCE, PASSED ONCE (INSTRUMENT LAWS): rungs 0-9 (10 witnesses, one per rung) built and verified
# against `fpc -Miso` 2026-09-03 by seat10. `--to 5` PASS 12/12 witness x mode. rung09_strings is a KNOWN
# RED rung (`--only 9` FAILs both modes) -- `a = 'foo'` (packed-array-of-char equality) hits SCRIP's
# "Run-time error 102 / numeric expected" (same class as the already-minted row
# pascal-fpc-class-runtime-102-numeric-expected; isolated directly: assignment+writeln alone passes,
# only the `=` comparison breaks) -- left red deliberately, not routed around, per this ladder's own
# purpose: a construct SCRIP does not yet support is exactly what a rung is for.
# EXIT: 0 every graded witness PASS in both modes · 1 any FAIL · 2 REFUSED (cannot measure).
set -u
# ⭐ THE BODY IS SHARED: every language's ladder runner is this stanza over lib_ladder.sh, which carries the
# interface, the population rule, the grading and the printed shape ONCE for all seven (row
# test-suite-consistency-seven-languages-one-standard, hq_T 2026-09-03). Only the three tokens below vary.
LADDER_LANG=Pascal; LADDER_SUITE=pascal; LADDER_EXT=.pas
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ladder.sh" || { echo "REFUSE (rc=2): cannot source lib_ladder.sh"; exit 2; }
ladder_main "$@"
