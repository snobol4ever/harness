#!/usr/bin/env bash
# run_crosscheck_csnobol4.sh — run Budne csnobol4-suite against an engine
#
# Usage: run_crosscheck_csnobol4.sh [--engine ENGINE] [--filter PATTERN] [--suite DIR]
#
# ENGINE: csnobol4 (default) or spitbol
#   csnobol4 — uses snobol4 -f -P256k
#   spitbol   — uses /home/claude/x64/bin/sbl -b
#
# Runs each test from its own directory so relative file opens (INPUT/OUTPUT) work.
# Uses temp files (not subshell capture) to handle binary/Latin-1 output safely.
# Skips: bench.sno genc.sno ndbm.sno sleep.sno time.sno line2.sno (no .ref or env-dependent).
#
# Exit: 0 if all pass, 1 if any fail.

set -euo pipefail

SUITE="${SUITE:-/home/claude/corpus/programs/csnobol4-suite}"
ENGINE="${ENGINE:-csnobol4}"
FILTER="${FILTER:-}"
SPITBOL="${SPITBOL:-/home/claude/x64/bin/sbl}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; RESET='\033[0m'
PASS=0; FAIL=0; SKIP=0
SKIP_LIST="bench.sno breakline.sno genc.sno k.sno line2.sno ndbm.sno sleep.sno time.sno"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --engine)  ENGINE="$2";  shift 2 ;;
        --filter)  FILTER="$2";  shift 2 ;;
        --suite)   SUITE="$2";   shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

case "$ENGINE" in
    csnobol4)
        if ! command -v snobol4 &>/dev/null; then
            echo "ERROR: snobol4 binary not found. See harness/oracles/csnobol4/BUILD.md"   # one-disk: not a path
            exit 1
        fi
        ENGINE_CMD=(snobol4 -f -P256k) ;;
    spitbol)
        if [[ ! -x "$SPITBOL" ]]; then
            echo "ERROR: SPITBOL binary not found at $SPITBOL"
            exit 1
        fi
        ENGINE_CMD=("$SPITBOL" -b) ;;
    *)
        echo "ERROR: Unknown engine '$ENGINE'. Use csnobol4 or spitbol."
        exit 1 ;;
esac

TMP_GOT=$(mktemp)
trap 'rm -f "$TMP_GOT"' EXIT

run_test() {
    local sno="$1"
    local base
    base=$(basename "$sno")
    local name="${base%.sno}"
    local ref="${sno%.sno}.ref"
    local input="${sno%.sno}.input"
    local dir
    dir=$(dirname "$sno")

    [[ -n "$FILTER" && "$name" != *"$FILTER"* ]] && { SKIP=$((SKIP+1)); return; }

    for s in $SKIP_LIST; do
        [[ "$base" == "$s" ]] && { echo -e "${YELLOW}SKIP${RESET} $name (excluded)"; SKIP=$((SKIP+1)); return; }
    done

    if [[ ! -f "$ref" ]]; then
        echo -e "${YELLOW}SKIP${RESET} $name (no .ref)"
        SKIP=$((SKIP+1))
        return
    fi

    # cd into suite dir so relative file opens (INPUT/OUTPUT) resolve correctly
    if [[ -f "$input" ]]; then
        (cd "$dir" && timeout 15 "${ENGINE_CMD[@]}" "$base" < "$input") > "$TMP_GOT" 2>/dev/null || true
    else
        (cd "$dir" && timeout 15 "${ENGINE_CMD[@]}" "$base") > "$TMP_GOT" 2>/dev/null || true
    fi

    if cmp -s "$ref" "$TMP_GOT"; then
        echo -e "${GREEN}PASS${RESET} $name"
        PASS=$((PASS+1))
    else
        echo -e "${RED}FAIL${RESET} $name"
        diff "$ref" "$TMP_GOT" | head -8 | sed 's/^/      /' || true
        FAIL=$((FAIL+1))
    fi
}

echo "=== CSNOBOL4 suite crosscheck ==="
echo "engine: $ENGINE"
echo "suite:  $SUITE"
echo ""

for sno in "$SUITE"/*.sno; do
    [[ -f "$sno" ]] || continue
    run_test "$sno"
done

echo ""
echo "============================================"
echo -e "Results: ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}, ${YELLOW}$SKIP skipped${RESET}"
[[ $FAIL -eq 0 ]] && echo -e "${GREEN}ALL PASS${RESET}" && exit 0
exit 1
