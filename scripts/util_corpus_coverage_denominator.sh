#!/bin/bash
# corpus coverage denominator -- a COMMAND, never a constant (hq_C s272 SS1). Recomputes total-minus-exclusions
# on the live tree every run and prints its own inputs -- do not pin this script's output into a doc or goal file.
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CORPUS="$S4E/corpus"
[ -d "$CORPUS" ] || { echo "⛔ REFUSES: corpus not found at $CORPUS"; exit 2; }

count() {
    find "$1" -type f \( -name '*.sno' -o -name '*.icn' -o -name '*.pl' -o -name '*.sc' \
        -o -name '*.reb' -o -name '*.raku' -o -name '*.pas' \) 2>/dev/null | wc -l
}

TOTAL=$(count "$CORPUS")
echo "corpus coverage denominator -- recomputed live, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "root: $CORPUS"
echo "total program files (.sno .icn .pl .sc .reb .raku .pas): $TOTAL"
echo

EXCLUDED=0
report_exclusion() {
    local label="$1" path="$2"
    if [ -d "$path" ]; then
        local n; n=$(count "$path")
        EXCLUDED=$((EXCLUDED + n))
        echo "  EXCLUDE $label: $n files at $path"
    else
        MISSING_EXCL=$((MISSING_EXCL + 1))
        echo "  ⛔ EXCLUDE $label: NOT FOUND at $path"
    fi
}
MISSING_EXCL=0
# ⭐⭐ ONE AUTHORITY (ceo ruling 2026-08-27, ASK2). The exclusion set is NOT restated here. It is READ from
# corpus_coverage_manifest.tsv, which test_gate_corpus_coverage_classified.sh enforces against the live tree.
# ⛔ WHY THIS SCRIPT NO LONGER CARRIES ITS OWN LIST: it used to, and it drifted -- it predated Lon's 2026-08-27
# corpus/programs ruling (RULES.md:55) and kept counting that tree, so this script printed 3105 while the manifest
# said 3005. Two live instruments answering the same question with different numbers, and no label on either. A
# second hardcoded list cannot be kept in sync by discipline; the only fix that holds is to not have one.
MANIFEST="$(dirname "${BASH_SOURCE[0]}")/corpus_coverage_manifest.tsv"
[ -f "$MANIFEST" ] || { echo "⛔ REFUSES rc=2: manifest not found at $MANIFEST -- this script no longer carries its own"; echo "   exclusion list by ruling, so it cannot compute a denominator without it."; exit 2; }
NEXCL=0
while IFS=$'\t' read -r kind path bucket evidence; do
    [ "$kind" = "EXCLUDE" ] || continue
    NEXCL=$((NEXCL + 1))
    report_exclusion "$path -- $evidence" "$CORPUS/$path"
done < <(grep -v '^[[:space:]]*#' "$MANIFEST" | grep -v '^[[:space:]]*$')
[ "$NEXCL" -gt 0 ] || { echo "⛔ REFUSES rc=2: manifest declares ZERO exclusions -- unparseable or truncated."; echo "   A denominator equal to the raw total is almost certainly wrong, so this refuses rather than print it."; exit 2; }

if [ "$MISSING_EXCL" -ne 0 ]; then
    echo
    echo "⛔ REFUSES rc=2: $MISSING_EXCL of $NEXCL declared exclusion path(s) did not resolve on this tree."
    echo "   Printing TOTAL-minus-what-happened-to-resolve would be a plausible and WRONG denominator -- exactly the"
    echo "   failure this instrument exists to prevent. Either the checkout is stale (pull) or the manifest is."
    exit 2
fi
echo
echo "DENOMINATOR = $TOTAL - $EXCLUDED = $((TOTAL - EXCLUDED))"
# ⭐ The label is part of the number (ceo ASK2): an unlabelled second denominator may not print anywhere.
echo "exclusion set: $NEXCL prefix(es), read from $(basename "$MANIFEST") -- the single denominator authority."
echo "authority gate: ../harness/scripts/test_gate_corpus_coverage_classified.sh"
