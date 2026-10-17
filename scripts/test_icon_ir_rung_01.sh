#!/bin/bash
# run_rung01.sh — run Rung 1 corpus against a compiled icon binary
# Usage: bash run_rung01.sh <icon-binary>
# The binary must accept an .icn filename as its first argument and
# print output to stdout.
#
# Also usable with the oracle directly:
#   bash run_rung01.sh oracle
# which runs all .icn files through icont+iconx.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.

set -e
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CORPUS="${CORPUS_REPO:-$(cd "$SCRIPT_DIR/../../.." && pwd)/corpus}/icon"

TIMEOUT="${TIMEOUT:-5}"
BINARY="${1:-}"
PASS=0
FAIL=0

if [[ "$BINARY" == "oracle" ]]; then
    . "$SCRIPT_DIR/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255), Icon-aware since row icon-oracle-accessors-shared." >&2; exit 3; }
    ICONT="${ICONT:-$(icont_bin)}" || exit 2
    ICONX="${ICONX:-$(iconx_bin)}" || exit 2
fi

for icn in "$CORPUS"/rung01_paper_*.icn; do
    base=$(basename "$icn" .icn)
    expected="$CORPUS/${base}.ref"

    if [[ "$BINARY" == "oracle" ]]; then
        cp "$icn" /tmp/_icon_test_${base}.icn
        cd /tmp && "$ICONT" -s "_icon_test_${base}.icn" 2>/dev/null
        actual=$(timeout -k 5 "$TIMEOUT" "$ICONX" "/tmp/_icon_test_${base}" 2>/dev/null)
    else
        actual=$(timeout -k 5 "$TIMEOUT" "$BINARY" "$icn" 2>/dev/null)
    fi

    if [[ "$actual" == "$(cat "$expected")" ]]; then
        echo "PASS  $base"
        PASS=$((PASS+1))
    else
        echo "FAIL  $base"
        echo "  expected: $(cat "$expected" | tr '\n' '|')"
        echo "  actual:   $(echo "$actual" | tr '\n' '|')"
        FAIL=$((FAIL+1))
    fi
done

echo ""
echo "$PASS PASS  $FAIL FAIL"
[[ $FAIL -eq 0 ]]
