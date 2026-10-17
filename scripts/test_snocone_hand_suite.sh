#!/usr/bin/env bash
# test_snocone_hand_suite.sh -- SC-18: run hand-crafted Snocone tests (SC-13..SC-17)
# Gate: PASS=5 FAIL=0 under BOTH real modes (--run m3, --compile m4)
#
# B-9 FIX (BOARD): MODES was (--run --run --run) -- --compile was never
# exercised. See ../harness/scripts/test_gate_sn7_beauty_self_host.sh for the same
# class fixed the same session.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). This runner had NO binary preflight at all -- not even an existence check --
# so `make`-less it would have graded a nonexistent binary into a full, plausible, entirely false all-FAIL
# board. The shim covers both: missing REFUSES, stale REFUSES, each rc=2 with the cure printed. NO LOGIC HERE:
# util_require_fresh.sh sources gate_require_fresh from lib_gate.sh, the ONE authority (hq_B 4c7253e99).
"$HERE/util_require_fresh.sh" --gate test_snocone_hand_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
TESTDIR="$HERE/../../corpus/tests/scrip_test/snocone"
TIMEOUT="${TIMEOUT:-8}"
GREEN='\033[0;32m'; RED='\033[0;31m'; RESET='\033[0m'

TESTS=(fibonacci palindrome wordcount quicksort pattern_suite)
MODES=(--run --compile)

PASS=0; FAIL=0

run_test() {
    local name="$1" mode="$2"
    local sc="$TESTDIR/${name}.sc"
    local ref="$TESTDIR/${name}.ref"
    if [[ ! -f "$sc" ]]; then echo -e "${RED}FAIL${RESET}  $name $mode (no .sc)"; FAIL=$((FAIL+1)); return; fi
    if [[ ! -f "$ref" ]]; then echo -e "${RED}FAIL${RESET}  $name $mode (no .ref)"; FAIL=$((FAIL+1)); return; fi
    local got; got=$(timeout -k 5 "$TIMEOUT" "$SCRIP" "$mode" "$sc" < /dev/null 2>/dev/null) || true
    local exp; exp=$(cat "$ref")
    if [[ "$got" == "$exp" ]]; then
        echo -e "${GREEN}PASS${RESET}  $name $mode"; PASS=$((PASS+1))
    else
        echo -e "${RED}FAIL${RESET}  $name $mode"
        diff <(echo "$exp") <(echo "$got") | head -10
        FAIL=$((FAIL+1))
    fi
}

echo "=== Snocone hand suite ==="
for name in "${TESTS[@]}"; do
    for mode in "${MODES[@]}"; do
        run_test "$name" "$mode"
    done
done

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
