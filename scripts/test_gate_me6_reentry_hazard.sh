#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_me6_reentry_hazard.sh — ME-6b gate
#
# Validates that SM_DEFINE_ENTRY does NOT re-push rbp when a user-function
# body jumps back to its own define-entry label (the icase hazard).
# Prior to ME-6a this pattern segfaulted under --run because every
# :(self) goto caused an additional `push rbp` without a paired pop.
#
# Gate criterion:
#   --run produces the correct output for both test patterns.
#   No segfault. Exit 0.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -e
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
PASS=0; FAIL=0

run_test() {
    local name="$1" src="$2" expected="$3"
    local tmp; tmp=$(mktemp /tmp/me6b_XXXXXX.sno)
    printf '%s' "$src" > "$tmp"
    local got
    got=$("$SCRIP" --run "$tmp" 2>/dev/null)
    rm -f "$tmp"
    if [ "$got" = "$expected" ]; then
        echo "  PASS $name"
        PASS=$((PASS+1))
    else
        echo "  FAIL $name (got='$got' expected='$expected')"
        FAIL=$((FAIL+1))
    fi
}

# Pattern 1: icase-style loop with goto self
run_test "self_goto_loop" \
"        DEFINE('COUNT(N,ACC)')
COUNT   EQ(N,0)     :S(CRET)
        ACC = ACC + 1
        N = N - 1   :(COUNT)
CRET    COUNT = ACC :(RETURN)
        OUTPUT = COUNT(5,0)
END" "5"

# Pattern 2: recursion (ensures rbp is correctly saved/restored across calls)
run_test "recursive_fib_7" \
"        DEFINE('FIB(N)')
FIB     LE(N,1)     :S(FIBRET)
        FIB = FIB(N - 1) + FIB(N - 2) :(RETURN)
FIBRET  FIB = N     :(RETURN)
        OUTPUT = FIB(7)
END" "13"

# Pattern 3: combined — self-goto loop AND recursion in same program
run_test "combined_loop_and_recursion" \
"        DEFINE('FIB(N)')
        DEFINE('COUNT(N,ACC)')
FIB     LE(N,1)     :S(FIBRET)
        FIB = FIB(N - 1) + FIB(N - 2) :(RETURN)
FIBRET  FIB = N     :(RETURN)
COUNT   EQ(N,0)     :S(CRET)
        ACC = ACC + 1
        N = N - 1   :(COUNT)
CRET    COUNT = ACC :(RETURN)
        OUTPUT = FIB(7)
        OUTPUT = COUNT(10,0)
END" "13
10"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
