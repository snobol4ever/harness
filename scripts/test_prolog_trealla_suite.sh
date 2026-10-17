#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${TREALLA_PROLOG_SUITE:=${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus/packages/prolog/trealla_tests}" || exit 2
# test_prolog_trealla_suite.sh -- THE TreallaTests SUITE ROW: the Trealla Prolog test programs (corpus/packages/prolog/trealla_tests, vendored by hq_pascal on
# the ceo's CEO-1595 under MODE SEPTET; 456 shipped = 329 graded, 30 of them through DRIVERS.tsv, + 125 UNGRADABLE + 2 UNGRADED, inventory_line rc 0),
# graded in both SCRIP modes against refs cut from swipl -q 9.0.4. 41 graded programs load with an error on stderr and still print, so their refs are swipl's
# output on the part it loaded (the package README names them). The coo builds the row's runner and grades it (hq_pascal, 2026-10-10: "Its suite row and
# runner are yours"). The body is lib_container_package_runner.sh, which grades through corpus_suite_harness.py run (its population floor refuses an empty
# container).
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib_container_package_runner.sh" || { echo "⛔ REFUSE(rc=2): lib_container_package_runner.sh unloadable"; exit 2; }
container_package_run prolog pl trealla "$TREALLA_PROLOG_SUITE" test_prolog_trealla_suite
