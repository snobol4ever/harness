#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_pre_step_tool_matches_icont_e.sh -- SCRIP'S OWN ICON PRE-STEP, out/scrip-ipp (JCON's preprocessor in Icon, compiled by
# scrip), WRITES THE TEXT THE ORACLE'S icont -E WRITES, ON EVERY CORPUS .icn (Lon 2026-09-30: "So we want to provide for SCRIP the IPP,
# Icon Pre Processor, as a pre-step." · "Let's use JCON's full pre-processor written in Icon as our IPP if it looks good." · "Do not use
# the oracle's pre-process step if it is part of the product"; RULES.md FACT RULE SCRIP DOES NOT PREPROCESS; GOAL-CEO.md CEO-1366).
#
# THE CONTRACT: for every corpus program (tests, packages, benchmarks, demos; ALL.* containers excluded), run in its own directory with
# LPATH naming the IPL include directories: whenever icont -E exits 0 the pre-step exits 0 and its PROGRAM TEXT is identical -- the
# lines that are not line-sync (a "#line N" directive or an empty line) compared in order, because the two preprocessors spell the
# line sync differently (Arizona replaces a directive line by an empty line and writes #line after a skipped region; JCON fills a gap
# under 20 lines with empty lines and writes #line otherwise) and SCRIP's lexer maps both to the same source line (measured: an error
# on source line 4 is named line 4 through either); and whenever icont -E refuses, the pre-step refuses (Arizona's own preprocessor
# tests tpp*.icn carry deliberate $error, unterminated and missing-include arms; a Scrip polyglot demo carries $import, not Icon's).
# The oracle is the GATE here, never a step of the product. PROVEN FAIL-ONCE: IPP_BIN=/bin/true reads FAIL on every file. ~30 s.
# Exit 0 = every file agrees; 1 = a disagreement, named; 2 = cannot measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G="$(basename "${BASH_SOURCE[0]}" .sh)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"; CORPUS="${CORPUS:-$S4E/corpus}"
TOOL="${IPP_BIN:-$ROOT/out/scrip-ipp}"; [ -x "$TOOL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no pre-step at $TOOL -- make"; exit 2; }
ICONT=/home/resources/icon-master/bin/icont; [ -x "$ICONT" ] || { echo "⛔ GATE REFUSE(2) [$G]: no icont at $ICONT"; exit 2; }
[ -d "$CORPUS/tests/icon" ] || { echo "⛔ GATE REFUSE(2) [$G]: no corpus at $CORPUS"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
export LPATH="$CORPUS/packages/icon/ipl/incl:$CORPUS/packages/icon/ipl/gincl"
find "$CORPUS" -type f -name '*.icn' -not -name 'ALL.*' -not -path '*/.git/*' | sort > "$T/list"
N=$(wc -l < "$T/list"); [ "$N" -gt 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: no .icn under $CORPUS"; exit 2; }
text() { grep -v '^#line ' "$1" | grep -v '^[[:space:]]*$'; }
same=0; sync=0; bad=0; both_err=0
while IFS= read -r f; do
    d=$(dirname "$f"); b=$(basename "$f")
    ( cd "$d" && timeout -k 5 20 "$TOOL" "$b" < /dev/null > "$T/a" 2> /dev/null ); ta=$?
    ( cd "$d" && timeout -k 5 20 "$ICONT" -E "$b" < /dev/null > "$T/b" 2> /dev/null ); tb=$?
    if [ "$tb" -eq 0 ]; then
        if [ "$ta" -ne 0 ]; then bad=$((bad + 1)); echo "  FAIL ${f#$CORPUS/}: the pre-step refused (rc=$ta) where icont -E accepts"
        elif cmp -s "$T/a" "$T/b"; then same=$((same + 1))
        elif cmp -s <(text "$T/a") <(text "$T/b"); then sync=$((sync + 1))
        else bad=$((bad + 1)); echo "  FAIL ${f#$CORPUS/}: program text differs: $(diff <(text "$T/a") <(text "$T/b") | grep -m1 '^[<>]' | cut -c1-100)"; fi
    else
        if [ "$ta" -ne 0 ]; then both_err=$((both_err + 1)); else bad=$((bad + 1)); echo "  FAIL ${f#$CORPUS/}: icont -E refuses (rc=$tb) and the pre-step accepted"; fi
    fi
done < "$T/list"
echo "  $N corpus programs: $same byte-identical, $sync identical but for the line-sync form, $both_err refused by both, $bad disagree"
[ "$((same + sync + both_err + bad))" -eq "$N" ] || { echo "⛔ GATE REFUSE(2) [$G]: the counts do not cover the population"; exit 2; }
[ "$bad" -eq 0 ] && echo "GATE PASS(0) [$G]: the pre-step matches icont -E on all $N corpus programs" || echo "⛔ GATE FAIL(1) [$G]: the pre-step disagrees with icont -E on $bad of $N"
[ "$bad" -eq 0 ]
