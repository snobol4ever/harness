#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${UNICON_SUITE:=${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus/packages/icon/unicon_tests}" || exit 2
# test_icon_unicon_suite.sh -- THE UniTests SUITE ROW (ceo CEO-2072/2074; hq_unicon): Unicon's own tests (corpus/packages/icon/unicon_tests, vendored from /home/resources/unicon/tests by
# util_vendor_unicon_tests.sh) as ONE container (ALL.icn / ALL.ref / ALL.csv, built by util_build_package_suite.py --lang icon --twice under CONTRACT.tsv oracle=unicon: every ref is cut
# from the Unicon translator through unicon_bin(), never from a .std alone and never from SCRIP), graded in both SCRIP modes. A SCRIP Icon program with a class, package, import or
# method header is a Unicon program (ARCH-UNICON.md R1); the oracle of these programs is unicon, the oracle of plain Icon stays Arizona icont (the Icon suites do not move). What the
# oracle cannot answer, graphics, database, the monitoring family and the bench library modules are named in EXCLUDED.tsv with their class and reason and leave the denominator.
# The body is lib_container_package_runner.sh with CPR_DEPTH=2 (category/NAME.icn).
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib_container_package_runner.sh" || { echo "⛔ REFUSE(rc=2): lib_container_package_runner.sh unloadable"; exit 2; }
CPR_DEPTH=2 container_package_run icon icn unitests "$UNICON_SUITE" test_icon_unicon_suite
