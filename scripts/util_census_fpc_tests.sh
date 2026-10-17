#!/usr/bin/env bash
# util_census_fpc_tests.sh -- Phase 1 of row `fpc-tests-vendor-script-run`: sweep-classify every
# .pp/.pas file under /home/resources/FPCSource/tests/ by SCRIP Pascal front-end verdict. This is a
# CENSUS, not a grader -- it produces the classification list Phase 2 (vendor the COMPILING subset,
# capture refs from the fpc 3.2.2 oracle) and Phase 3 (test_pascal_fpc_suite.sh) build on. Does not
# touch corpus/ or FPCSource/ -- read-only census, symlinks live in a scratch dir only.
#
# FPCSource files use .pp, which SCRIP's driver does not recognize (falls through to snobol4 dispatch
# -- confirmed by hand) -- every file is symlinked to a .pas name in a scratch dir before compiling.
#
# Classes (by ./scrip --compile verdict, timeout-guarded):
#   COMPILE  -- rc=0, a real .s file was produced. Phase 2 vendoring candidate.
#   REJECT   -- rc=1 (or any non-zero, non-timeout, non-crash-signal code) with a "parse error" or
#               similar front-end message -- SCRIP correctly refuses a construct it doesn't support.
#               Counted and NAMED, never silent, per this row's own GOAL text.
#   CRASH    -- killed by a signal (rc >= 128, i.e. rc-128 is the signal number) -- SIGSEGV etc. Real
#               bugs, distinct from a clean REJECT.
#   TIMEOUT  -- exceeded the per-file budget. Distinct bucket, not folded into CRASH (an rc=124 is not
#               a measurement of WHY it didn't finish, same lesson RULES.md's "an rc is not a
#               measurement of time" already states for a different row -- do not assume hang).
#
# Output: one line per file to stdout (class|relpath|first-diagnostic-line, truncated), plus a final
# CENSUS_BOARD summary line to stderr so a caller can `tee` the full list and still grep the board.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${HERE}/../../SCRIP/scrip"
FPC_TESTS="${FPC_TESTS_DIR:-/home/resources/FPCSource/tests}"
TIMEOUT="${CENSUS_TIMEOUT:-5}"

[ -x "$SCRIP" ]      || { echo "⛔ REFUSED-TO-GRADE: scrip not built" >&2; exit 2; }
[ -d "$FPC_TESTS" ]  || { echo "⛔ REFUSED-TO-GRADE: $FPC_TESTS missing" >&2; exit 2; }

TMP="$(mktemp -d /tmp/fpc_census_XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

COMPILE=0; REJECT=0; CRASH=0; TIMEOUT_N=0; TOTAL=0
n=0
while IFS= read -r f; do
    n=$((n+1))
    rel="${f#"$FPC_TESTS"/}"
    link="$TMP/f${n}.pas"
    ln -sf "$f" "$link"
    out="$TMP/f${n}.s"
    log="$TMP/f${n}.log"
    timeout -k 5 "$TIMEOUT" "$SCRIP" --compile "$link" -o "$out" < /dev/null > "$log" 2>&1
    rc=$?
    diag="$(head -1 "$log" | cut -c1-100)"
    if [ "$rc" -eq 0 ] && [ -s "$out" ]; then
        COMPILE=$((COMPILE+1)); echo "COMPILE|$rel|$diag"
    elif [ "$rc" -eq 124 ]; then
        TIMEOUT_N=$((TIMEOUT_N+1)); echo "TIMEOUT|$rel|$diag"
    elif [ "$rc" -ge 128 ]; then
        CRASH=$((CRASH+1)); echo "CRASH|$rel|rc=$rc $diag"
    else
        REJECT=$((REJECT+1)); echo "REJECT|$rel|$diag"
    fi
    TOTAL=$((TOTAL+1))
done < <(find "$FPC_TESTS" -name "*.pp" -o -name "*.pas" | sort)

echo "CENSUS_BOARD total=$TOTAL compile=$COMPILE reject=$REJECT crash=$CRASH timeout=$TIMEOUT_N" >&2
[ "$((COMPILE + REJECT + CRASH + TIMEOUT_N))" -eq "$TOTAL" ] || { echo "⛔ BUCKET COUNTS DON'T SUM -- instrument bug" >&2; exit 2; }
