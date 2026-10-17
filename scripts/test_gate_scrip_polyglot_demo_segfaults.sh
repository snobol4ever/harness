#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_scrip_polyglot_demo_segfaults.sh -- DONE-WHEN for scrip-polyglot-demo-3-segfaults.
# The three named polyglot demos under corpus/demos/scriptix/demoNN/ must not crash the compiler.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -u
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus}"

fail() { echo "⛔ NOT DONE: $*" >&2; exit 1; }
# ⛔⭐ PID-SCOPED SCRATCH, NEVER A BARE FIXED /tmp NAME (PROTOCOL s266). This gate wrote its stderr to
# /tmp/_scrip_demo_segv_err -- ONE filename shared by every seat in the fleet. It cannot flip the verdict
# (rc comes from the direct exit status, not the file), but it can attach ANOTHER SEAT'S error text to a
# real failure, which is worse than no text: it sends the reader after a cause that belongs to someone
# else's run. seat04 measured exactly this race on `done`'s re-verification at a shared name.
ERRF="$(mktemp "${TMPDIR:-/tmp}/scrip_demo_segv.$$.XXXXXX")"
trap 'rm -f "$ERRF"' EXIT

[ -x "$SCRIP" ] || fail "scrip not built at $SCRIP -- run 'make pristine' in SCRIP/ first"

for f in demo02/wordcount demo04/palindrome demo06/sieve; do
    src="$CORPUS/demos/scriptix/$f.md"
    [ -f "$src" ] || fail "witness not found: $src"
    timeout -k 5 8 "$SCRIP" --run "$src" < /dev/null > /dev/null 2>"$ERRF"
    rc=$?
    [ "$rc" -lt 128 ] || fail "$f still crashes (rc=$rc): $(cat "$ERRF")"
done
rm -f "$ERRF"

echo "✅ scrip-polyglot-demo-3-segfaults DONE-WHEN: none of the three named demos crash anymore"
exit 0
