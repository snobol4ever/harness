#!/usr/bin/env bash
# test_gate_ladder_forms_check_selftest.sh -- util_ladder_forms_check.py's own --selftest MUST run as part of
# the suite, not only by hand (hq_U, 2026-09-06: "GREEN-BY-HAND IS NOT COVERAGE -- if the suite is byte-
# identical with and without the guard, the guard is not wired, it is only present"). The instrument that
# grades every language's ladder DONE-WHEN carries its own hermetic selftest, and until this gate landed
# nothing but a human typing --selftest ever ran it.
#
# WHAT IT PROTECTS, CONCRETELY: the FIELD-COUNT GUARD in read_census() -- a census data row with a different
# number of tab-separated fields than its header declares must REFUSE, never get silently graded on the
# fields it happened to have. FAIL-ONCE PROVEN before this gate existed (seat08, row
# forms-check-field-count-guard-refuses-rc2-on-a-shape-it-cannot-grade): the pre-guard read_census() zero-
# padded a short row and the new selftest case read MISSING instead of REFUSED; landing the guard flipped it
# green. See FINDING-2026-09-06-seat08-ladder-tsv-embedded-newlines-broke-the-forms-check-for-every-row-after.md
# for the real-world incident this guards against.
#
# WHY THIS SHAPE: --selftest is hermetic (scratch tempdir, fabricated censuses, no real corpus, no build) and
# already returns the right exit code (0 every case passed / 1 a case regressed) -- this gate exists to be a
# LINE IN make test's own recipe, not to re-implement the check.
#
# rc=0 every selftest case passed / rc=1 a case regressed / rc=2 cannot run at all (script or python3 missing).
# FAIL-ONCE PROOF FOR THIS GATE ITSELF: revert the field-count check in read_census() (SCRIP git log, this
# row's landing commit) and re-run -- the "wrong field count REFUSES" selftest case must go red.
set -u
GATE_NAME=test_gate_ladder_forms_check_selftest
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/util_ladder_forms_check.py"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || refuse "python3 not on PATH"
[ -f "$SCRIPT" ] || refuse "$SCRIPT not found"
out="$(python3 "$SCRIPT" --selftest 2>&1)"; rc=$?
printf '%s\n' "$out"
if [ "$rc" -ne 0 ]; then
    echo "⛔ GATE RED [$GATE_NAME]: util_ladder_forms_check.py --selftest exited $rc"
    exit 1
fi
n="$(printf '%s\n' "$out" | grep -c '^SELFTEST: ')"
echo "GATE PASS(0) [$GATE_NAME]: util_ladder_forms_check.py --selftest, $n case(s)"
exit 0
