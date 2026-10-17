#!/usr/bin/env bash
# test_audit_bb_x86_exercise.sh — empirical audit: which BB pat-kinds actually
# reach emit_bb_xstar/xlnth/etc. via --compile across the SNOBOL4 corpus?
#
# Motivation: the 7 BB-side LIFT slices (SCRIP 045baf4a) moved 17 emit_bb_x*
# bodies into BB_templates/.  But the EC-UNI-REWIRE investigation
# (2026-05-21) found that beauty.sno --compile output contains only ONE
# `# BOX POS(0)` banner in 882901 bytes — the other 16 BB kinds are
# structurally invisible to the EC-UNI-21 gate.
#
# This script broadens the question: across EVERY .sno file in the corpus,
# count `# BOX ` banners by kind under --compile.  Output a histogram showing
# which kinds actually reach emit_bb_xstar/lnth/cat/arbno/etc. anywhere.
#
# Run before any EC-UNI-REWIRE work — the result is data needed to make the
# rewire path decision (a.1 / a.2 / b / c) Lon-actionable.
#
# Self-contained per RULES.md: paths derived from $0; no env deps required.
# Usage: bash ../harness/scripts/test_audit_bb_x86_exercise.sh
#         [optional: SUBSET=feat to limit to a corpus subtree]
#
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet 4.7
# DATE:    2026-05-21
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus}"
TIMEOUT="${TIMEOUT:-10}"
SUBSET="${SUBSET:-}"

if [ ! -x "$SCRIP" ]; then
    echo "SKIP scrip not built at $SCRIP"
    exit 0
fi
if [ ! -d "$CORPUS/tests/snobol4" ]; then
    echo "SKIP corpus not populated at $CORPUS"
    exit 0
fi

ROOT="$CORPUS/tests/snobol4"
if [ -n "$SUBSET" ]; then ROOT="$ROOT/$SUBSET"; fi

TMP="$(mktemp /tmp/bb_audit_XXXX.s)"
TMP_BANNERS="$(mktemp /tmp/bb_audit_banners_XXXX.txt)"
trap 'rm -f "$TMP" "$TMP_BANNERS"' EXIT

declare -A KIND_COUNT
declare -A KIND_FILES
TOTAL_FILES=0
COMPILED_OK=0
COMPILE_FAIL=0
TIMEOUT_COUNT=0
SEGFAULT_COUNT=0
ANY_BB_FILES=0

# Walk every .sno
while IFS= read -r sno; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    : > "$TMP"
    timeout -k 5 "$TIMEOUT" "$SCRIP" --compile "$sno" > "$TMP" 2>/dev/null < /dev/null
    rc=$?
    if [ $rc -eq 124 ]; then TIMEOUT_COUNT=$((TIMEOUT_COUNT + 1)); continue; fi
    if [ $rc -eq 139 ]; then SEGFAULT_COUNT=$((SEGFAULT_COUNT + 1)); continue; fi
    # Empty output (compile failure) — count it but continue
    bytes=$(wc -c < "$TMP")
    if [ "$bytes" -eq 0 ]; then COMPILE_FAIL=$((COMPILE_FAIL + 1)); continue; fi
    COMPILED_OK=$((COMPILED_OK + 1))
    # Extract BOX banners
    if grep -qE "^# BOX |^    # BOX " "$TMP"; then
        ANY_BB_FILES=$((ANY_BB_FILES + 1))
        # Capture relative path for histogram
        rel="${sno#$CORPUS/}"
        while IFS= read -r line; do
            # Extract kind from "# BOX KIND(args)" or "    # BOX KIND(args)"
            kind=$(echo "$line" | sed -nE 's/^\s*# BOX ([A-Z_]+).*$/\1/p')
            if [ -n "$kind" ]; then
                KIND_COUNT[$kind]=$((${KIND_COUNT[$kind]:-0} + 1))
                # Track unique files per kind (set membership via space-delimited list)
                if [[ " ${KIND_FILES[$kind]:-} " != *" $rel "* ]]; then
                    KIND_FILES[$kind]="${KIND_FILES[$kind]:-} $rel"
                fi
            fi
        done < <(grep -E "^# BOX |^    # BOX " "$TMP")
    fi
done < <(find "$ROOT" -name '*.sno' -type f | sort)

echo "=== BB x86 exercise audit ==="
echo "Corpus root:       $ROOT"
echo "Total .sno files:  $TOTAL_FILES"
echo "Compiled OK:       $COMPILED_OK"
echo "Compile failed:    $COMPILE_FAIL  (empty output)"
echo "Timed out:         $TIMEOUT_COUNT  (--compile took >${TIMEOUT}s)"
echo "Segfaulted:        $SEGFAULT_COUNT"
echo "Files emitting BB: $ANY_BB_FILES"
echo ""
echo "=== BB kind histogram (sorted by count desc) ==="
if [ ${#KIND_COUNT[@]} -eq 0 ]; then
    echo "  (no BB pat-level emissions across entire corpus under --compile)"
    echo "  This confirms emit_bb_x* path is near-dead in current SNOBOL4 corpus."
else
    for kind in "${!KIND_COUNT[@]}"; do
        printf "%-12s %4d  files=%d\n" "$kind" "${KIND_COUNT[$kind]}" "$(echo ${KIND_FILES[$kind]} | wc -w)"
    done | sort -k2 -rn
    echo ""
    echo "=== Per-kind first file (for quick reproducibility) ==="
    for kind in $(echo "${!KIND_COUNT[@]}" | tr ' ' '\n' | sort); do
        first=$(echo "${KIND_FILES[$kind]}" | awk '{print $1}')
        printf "%-12s  %s\n" "$kind" "$first"
    done
fi
echo ""
echo "Done."
