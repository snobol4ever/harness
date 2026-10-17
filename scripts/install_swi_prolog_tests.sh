#!/usr/bin/env bash
# install_swi_prolog_tests.sh — copy SWI-Prolog ISO conformance tests into corpus
# Source: https://github.com/SWI-Prolog/swipl-devel tests/core/
# Target: /home/claude/corpus/tests/prolog/swi_tests/
# Idempotent: skips files already present.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET=$S4E/corpus/tests/prolog/swi_tests
UPSTREAM=https://github.com/SWI-Prolog/swipl-devel.git
TMPDIR_BASE=/tmp/swi_install_$$

# Tests to install (new naming convention in swipl-devel master)
TESTS=(
    test_arith.pl
    test_bips.pl
    test_call.pl
    test_list.pl
    test_misc.pl
    test_string.pl
    test_term.pl
    test_exception.pl
    test_dcg.pl
)

mkdir -p "$TARGET"

# --- Check if all targets already present ---
ALL_PRESENT=1
for t in "${TESTS[@]}"; do
    [ -f "$TARGET/$t" ] || { ALL_PRESENT=0; break; }
done

if [ "$ALL_PRESENT" = "1" ]; then
    echo "SKIP: SWI test files already present in $TARGET"
    exit 0
fi

# --- Try to copy from local zip extraction (preferred in CI) ---
LOCAL_CORE=/tmp/swipl-devel-master/tests/core
if [ -d "$LOCAL_CORE" ]; then
    echo "Installing SWI tests from local extraction at $LOCAL_CORE ..."
    INSTALLED=0
    for t in "${TESTS[@]}"; do
        if [ -f "$LOCAL_CORE/$t" ]; then
            cp "$LOCAL_CORE/$t" "$TARGET/$t"
            echo "  copied $t"
            INSTALLED=$((INSTALLED+1))
        else
            echo "  WARN: $t not found in local core"
        fi
    done
    echo "Installed $INSTALLED/${#TESTS[@]} SWI test files."
    exit 0
fi

# --- Fall back to sparse git clone ---
echo "Installing SWI tests from $UPSTREAM ..."
mkdir -p "$TMPDIR_BASE"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

git clone --depth=1 --filter=blob:none --sparse "$UPSTREAM" "$TMPDIR_BASE/swipl" 2>/dev/null
cd "$TMPDIR_BASE/swipl"
git sparse-checkout set tests/core

INSTALLED=0
for t in "${TESTS[@]}"; do
    src="tests/core/$t"
    if [ -f "$src" ]; then
        cp "$src" "$TARGET/$t"
        echo "  copied $t"
        INSTALLED=$((INSTALLED+1))
    else
        echo "  WARN: $t not found in upstream"
    fi
done

echo "Installed $INSTALLED/${#TESTS[@]} SWI test files into $TARGET"
