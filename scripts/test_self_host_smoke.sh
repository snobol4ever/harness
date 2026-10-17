#!/usr/bin/env bash
# test_self_host_smoke.sh — SI-5 cross-check: self-hosted pipeline output must
# byte-match native scrip output on the same logical program.
#
# For each (hosted, native) pair below, run both via `scrip --run` and diff
# stdout.  The hosted invocation chains tree.sc + lower.sc + lower_driver.sc +
# sm_interp.sc + the *_interp.sc test driver; the native invocation runs the
# corresponding *_native.sc source directly.  Both must produce identical bytes.
#
# Idempotent.  No prerequisites beyond a built scrip and a corpus checkout.
# Self-contained per RULES.md — paths derived from $0, hardcoded corpus path,
# explicit timeout on every scrip call, < /dev/null for safety.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$SCRIP/scrip}"
CORPUS="$S4E/corpus"
SCRIP_DIR="$S4E/SCRIP/bootstrap"   # moved from corpus/SCRIP (RULES.md REPO BOUNDARY, Lon s267: the self-hosted Snocone frontend is compiler source, not a corpus program)

[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built at $SCRIP"; exit 2; }
[ -d "$SCRIP_DIR" ] || { echo "⛔ REFUSED-TO-GRADE corpus SCRIP dir missing: $SCRIP_DIR"; exit 2; }

pass=0
fail=0
for case in smoke_interp sm_interp_test si_06_exp si_07_pat_lit si_08_prim_pats si_09_pat_fns si_11_compare si_12_call_builtin si_13_proc si_14_computed_goto si_15a_literals si_15b_arith si_15c_pat_replace si_16_cond_return si_17a_assign si_17b_control ; do
    hosted_sc="$SCRIP_DIR/tests/${case}.sc"
    native_sc="$SCRIP_DIR/tests/${case}_native.sc"
    [ -f "$hosted_sc" ] || { echo "SKIP $case — hosted source missing"; continue; }
    [ -f "$native_sc" ] || { echo "SKIP $case — native source missing"; continue; }
    hosted_out="$(timeout -k 5 8 "$SCRIP" --run \
        "$SCRIP_DIR/tree.sc" \
        "$SCRIP_DIR/lower.sc" \
        "$SCRIP_DIR/lower_driver.sc" \
        "$SCRIP_DIR/sm_interp.sc" \
        "$hosted_sc" \
        < /dev/null)"
    native_out="$(timeout -k 5 8 "$SCRIP" --run "$native_sc" < /dev/null)"
    if [ "$hosted_out" = "$native_out" ] ; then
        echo "PASS $case  (hosted == native, $(echo "$hosted_out" | wc -l) lines)"
        pass=$((pass + 1))
    else
        echo "FAIL $case"
        echo "  --- hosted ---"
        echo "$hosted_out" | sed 's/^/    /'
        echo "  --- native ---"
        echo "$native_out" | sed 's/^/    /'
        fail=$((fail + 1))
    fi
done
echo "PASS=$pass FAIL=$fail"
[ $fail -eq 0 ] || exit 1
