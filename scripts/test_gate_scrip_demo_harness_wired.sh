#!/usr/bin/env bash
# test_gate_scrip_demo_harness_wired.sh -- DONE-WHEN for scrip-demo-harness-unwired.
# ../harness/scripts/test_scrip_demos.sh (sweeps corpus/demos/scriptix/demo*/*.scrip against .ref) exists but
# is referenced by NOTHING -- not the Makefile, not any board_*.sh/scorecard_*.sh aggregator --
# so its 8/10 FAIL (2026-08-27: 3 SEGFAULT + 5 Icon-semicolon-parse-error, see the two sibling
# rows this same pass minted) has never been visible to anyone who didn't think to run it by
# hand. This gate requires BOTH that it's wired into some real aggregator AND that it passes --
# satisfy the latter via the sibling rows' fixes, or by excluding a still-broken demo here with
# a documented reason (matching this audit's own GATED/UNGATED-with-a-row/EXCLUDED-with-a-reason
# framing), not by weakening this check.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -u
SCRIP_DIR="$S4E/SCRIP"

fail() { echo "⛔ NOT DONE: $*" >&2; exit 1; }

grep -rlq "test_scrip_demos" "$SCRIP_DIR/Makefile" "$SCRIP_DIR"/../harness/scripts/board_*.sh "$SCRIP_DIR"/../harness/scripts/scorecard_*.sh 2>/dev/null \
    || fail "test_scrip_demos.sh is still referenced by nothing (checked Makefile, board_*.sh, scorecard_*.sh)"
bash "$SCRIP_DIR/../harness/scripts/test_scrip_demos.sh" || fail "test_scrip_demos.sh is wired in but still failing"

echo "✅ scrip-demo-harness-unwired DONE-WHEN: test_scrip_demos.sh is wired into a real aggregator and passes"
exit 0
