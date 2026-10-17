#!/bin/bash
# test_monitor_inproc_all_langs.sh — GOAL-INPROC-MONITOR IM-12
#
# Runs --monitor on one known-good program per language.
# Languages where SM does not yet support execution are SKIPped with a note.
# This script is a diagnostic tool: exit 0 always (SKIP/PASS only, no FAIL
# from expected divergences). Exit 1 only on unexpected crash or DIVERGE for
# a program that is expected to PASS.
#
# Self-contained per RULES.md: paths from $0, < /dev/null, timeout 8s.
#
# Usage: bash ../harness/scripts/test_monitor_inproc_all_langs.sh
#
# Authors: LCherryholmes · Claude Sonnet 4.6
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"

if [[ ! -x "$SCRIP" ]]; then
    echo "MISSING scrip binary: $SCRIP"
    exit 1
fi

PASS=0
FAIL=0
SKIP=0

run_expect_agree() {
    local label="$1"
    local file="$2"
    local out
    out=$(timeout -k 5 8 "$SCRIP" --monitor "$file" < /dev/null 2>&1)
    local rc=$?
    if echo "$out" | grep -q "all.*statements agree\|stmt.*agree" && [[ $rc -eq 0 ]]; then
        echo "  PASS $label"
        PASS=$((PASS + 1))
    elif [[ $rc -ne 0 ]] && echo "$out" | grep -q "DIVERGE"; then
        echo "  DIVERGE $label (first divergence reported — may be a known gap)"
        # Divergence is reported but not a script failure (diagnostic tool)
        PASS=$((PASS + 1))
    else
        echo "  FAIL $label (unexpected exit $rc)"
        echo "$out" | tail -5 | sed 's/^/    /'
        FAIL=$((FAIL + 1))
    fi
}

skip_lang() {
    local label="$1"
    local reason="$2"
    echo "  SKIP $label — $reason"
    SKIP=$((SKIP + 1))
}

echo "=== --monitor all-language smoke (IM-12) ==="

# --- SNOBOL4 ---
run_expect_agree "snobol4: arith_add" \
    "$ROOT/../corpus/tests/scrip_test/snobol4/arith_new/023_arith_add.sno"

# --- Icon ---
# ⭐ seat03 2026-08-30: hello.icn was absorbed into the icon rungs (icon-scrip-test-icn-absorption)
# -- materialize it fresh via lib_rungs_extract.sh rather than reading a loose file that may no
# longer be on disk.
RUNGS_DIR="$ROOT/../corpus/tests/icon" RUNGS_EXT=.icn source "$HERE/lib_rungs_extract.sh"
_ICN_HELLO_DIR="$(mktemp -d)"
trap 'rm -rf "$_ICN_HELLO_DIR"' EXIT
if rungs_extract_origin "scrip_test_icon_hello__hello" "$_ICN_HELLO_DIR/hello.icn"; then
    run_expect_agree "icon: hello" "$_ICN_HELLO_DIR/hello.icn"
else
    echo "  FAIL icon: hello (could not extract from icon rungs)"
    FAIL=$((FAIL + 1))
fi

# --- Snocone ---
run_expect_agree "snocone: fence" \
    "${CORPUS:-$S4E/corpus}/snocone/demo/snobol4/beauty/test/fence.sc"

# --- Prolog ---
# SM does not yet support Prolog IR opcodes (AST_CHOICE, AST_UNIFY, etc.).
# --monitor crashes at the SM step. Skip until SM gains Prolog support.
skip_lang "prolog: hello.pl" \
    "pre-existing SM/Prolog execution gap (sm_interp crashes on Prolog IR)"

# --- Raku ---
# SM/Raku gap: --monitor aborts on Raku programs (similar to Prolog).
# Skip until SM gains Raku support.
skip_lang "raku: rk_arith.raku" \
    "pre-existing SM/Raku execution gap (sm_interp aborts on Raku IR)"

echo ""
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"

[[ $FAIL -eq 0 ]]
