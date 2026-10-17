#!/bin/bash
# census_r12.sh — R12-EXIT census: how many corpus programs still EMIT r12 (mode-4 .s scan).
# Usage: bash ../harness/scripts/census_r12.sh [outfile-list]   (writes the emitting-program list to $1 or /tmp/r12_list.txt)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../../SCRIP"
CORPUS="${CORPUS:-$S4E/corpus}"
LIST="${1:-/tmp/r12_list.txt}"
: > "$LIST"
total=0; hits=0
while IFS= read -r sno; do
    total=$((total+1))
    s=$(mktemp --suffix=.s)
    if ./scrip --compile "$sno" > "$s" 2>/dev/null; then
        if grep -q 'r12' "$s"; then hits=$((hits+1)); echo "$(basename "${sno%.sno}")" >> "$LIST"; fi
    fi
    rm -f "$s"
done < <(find "$CORPUS/crosscheck" -name "*.sno" 2>/dev/null | sort)
echo "r12 emitters: $hits / $total   (list: $LIST)"
