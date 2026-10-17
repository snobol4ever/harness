#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${ROSETTA_PASCAL_SUITE:=${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus/packages/pascal/rosetta-pascal}" || exit 2
# test_pascal_rosetta_suite.sh -- THE Rosetta Pascal SUITE ROW: every Pascal solution on Rosetta Code (corpus/packages/pascal/rosetta-pascal, vendored
# from RosettaCodeData), graded in both SCRIP modes against refs cut from fpc -Miso. Lon 2026-10-09, in-chat to the coo, verbatim: "Let's get
# rosseta for both Pascal and Prolog on the official test suite banner. Graded against the oracle." The body is lib_container_package_runner.sh, which grades through corpus_suite_harness.py run (its population floor refuses an empty container).
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib_container_package_runner.sh" || { echo "⛔ REFUSE(rc=2): lib_container_package_runner.sh unloadable"; exit 2; }
container_package_run pascal pas rosetta-pascal "$ROSETTA_PASCAL_SUITE" test_pascal_rosetta_suite
