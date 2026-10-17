#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${PUZZLES_PROLOG_SUITE:=${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus/packages/prolog/puzzles}" || exit 2
# test_prolog_puzzles_suite.sh -- THE ProPuzzles SUITE ROW: every Prolog puzzle program set found with a stated licence (corpus/packages/prolog/puzzles --
# hakank's SWI and SICStus models, Rosetta's puzzle tasks, the 99 problems, Bratko, PrologPuzzles; Lon 2026-10-09, in-chat to the ceo, verbatim: "We want every
# Prolog puzzle program sets we can find."; CEO-1583), graded in both SCRIP modes against refs cut from swipl -q; the CLP(FD) programs ride in the container as
# EXCLUDED.tsv class OUTSIDE_CLPFD (CEO-579, CEO-1593) and show in the Excl column until the FD rows of ARCH-PROLOG-CLPFD.md close. The row was opened by the ceo
# on Lon's word 2026-10-10 (CEO-1606: "Ensure that the new rows in the test suite banner for all the new test suites are inserted"); the coo grades it. The body
# is lib_container_package_runner.sh, which grades through corpus_suite_harness.py run (its population floor refuses an empty container).
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib_container_package_runner.sh" || { echo "⛔ REFUSE(rc=2): lib_container_package_runner.sh unloadable"; exit 2; }
container_package_run prolog pl puzzles "$PUZZLES_PROLOG_SUITE" test_prolog_puzzles_suite
