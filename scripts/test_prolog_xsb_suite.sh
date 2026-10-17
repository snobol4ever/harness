#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${XSB_PROLOG_SUITE:=${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus/packages/prolog/xsb_tests}" || exit 2
# test_prolog_xsb_suite.sh -- THE XsbTests SUITE ROW (ceo CEO-1718, 2026-10-14: a vendored package with refs and no row is DARK, worse than red):
# the XSB test programs (corpus/packages/prolog/xsb_tests, vendored on the ceo's CEO-1595; one flat container, ALL.pl / ALL.ref / ALL.csv, built
# by util_build_package_suite.py --lang prolog --twice), graded in both SCRIP modes against refs cut from swipl -q -- never from XSB's own
# <test>_old expected files (ONE ORACLE) -- each program run in SCRIP's SWI dialect by the package's ALL.prelude (CEO-1712, corpus 484d47cfa).
# The overlap the README names: swi_tests/xsb carries a plunit packaging of part of the same XSB suite (387 files against this package's 908),
# a different harness and denominator, so a cure is claimed in the row whose reading moved. The body is lib_container_package_runner.sh, which
# grades through corpus_suite_harness.py run (its population floor refuses an empty container).
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib_container_package_runner.sh" || { echo "⛔ REFUSE(rc=2): lib_container_package_runner.sh unloadable"; exit 2; }
container_package_run prolog pl xsb "$XSB_PROLOG_SUITE" test_prolog_xsb_suite
