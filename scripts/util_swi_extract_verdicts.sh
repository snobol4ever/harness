#!/bin/bash
# util_swi_extract_verdicts.sh -- run ONE SWI plunit .pl file under the LIVE swipl oracle and report
# declared/pass/fail counts plus failing test names. Building block for hq_C s272 SS3 ("grade against
# swipl directly now that it exists") -- NOT yet wired into a SCRIP-vs-oracle comparison; see
# postoffice/tasks/audit-corpus-what-is-ungated.task.md for why that wiring is a separate, larger step
# (test( names collide within a single suite -- e.g. test_format.pl declares "radix" three times -- so
# matching swipl's verdicts against SCRIP plunit.pl's own per-test output must be ordinal, not by name).
# Usage: util_swi_extract_verdicts.sh <file.pl>
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib_oracle_flags.sh"
SWIPL="$(swipl_bin)" || exit 2

F="${1:-}"
[ -n "$F" ] && [ -f "$F" ] || { echo "⛔ REFUSES: usage: $0 <file.pl>"; exit 2; }

DECLARED=$(grep -c '^test(' "$F")
[ "$DECLARED" -gt 0 ] || { echo "⛔ REFUSES: no test( declarations in $F -- not a plunit test body (entry-point wrapper file?)"; exit 2; }

RAW=$(mktemp)
"$SWIPL" -q -g "consult('$F'), run_tests, halt" -t "halt(1)" > "$RAW" 2>&1
RC=$?
# NOTE: capture $? immediately after the command that sets it -- piping this line through
# tail/grep before checking rc silently corrupts it to the pipe's last stage's exit status.

FAIL_COUNT=$(grep -cP '^ERROR: .+\.pl:[0-9]+:$' "$RAW")
PASS_COUNT=$((DECLARED - FAIL_COUNT))

echo "file: $F"
echo "swipl exit: $RC   declared: $DECLARED   pass: $PASS_COUNT   fail: $FAIL_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "failing test names (source-declared, ordinal position not resolved here -- may collide):"
    grep -oP '^\ttest \K[a-zA-Z0-9_]+' "$RAW" | sed 's/^/  /'
fi
if [ "$PASS_COUNT" -lt 0 ]; then
    echo "⛔ SANITY FAIL: fail count ($FAIL_COUNT) exceeds declared ($DECLARED) -- consult likely errored before run_tests reached every suite; do not trust these numbers"
fi
rm -f "$RAW"
