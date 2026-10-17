#!/usr/bin/env bash
# ../harness/scripts/test_scrip_demos.sh — run all scrip demo/*.md files via --run and compare to .ref
#
# Self-contained. Run from anywhere with no env vars.
# Usage: bash ../harness/scripts/test_scrip_demos.sh
# Exit:  0 = all PASS, 1 = any FAIL
#
# Authors: LCherryholmes · Claude Sonnet 4.6

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
CORPUS="$(cd "$ROOT/.." && pwd)/corpus"
SCRIP="${SCRIP:-$ROOT/scrip}"
DEMO_DIR="$CORPUS/demos/scriptix"
TIMEOUT=8
PASS=0; FAIL=0; SKIP=0

if [ ! -x "$SCRIP" ]; then
    echo "ERROR: scrip not found at $SCRIP — run build_scrip.sh first" >&2
    exit 1
fi

check() {
    local label="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo "  PASS $label"
        PASS=$((PASS+1))
    else
        echo "  FAIL $label"
        # Show first differing line
        diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | head -6 | sed 's/^/       /'
        FAIL=$((FAIL+1))
    fi
}

echo "=== scrip demo suite (--run) ==="
echo ""

# demo1 — Hello World (SNO + Icon + Prolog, each prints once → 3 lines)
# demo2 — Word Count   (SNO + Icon each print 9 → 2 lines)
# Each demo's .ref reflects what --run produces for the full polyglot .md.
# If .ref was written for a single-language run it will be updated here as we go.

for demo_dir in "$DEMO_DIR"/demo*/; do
    dname=$(basename "$demo_dir")
    md=$(ls "$demo_dir"*.md 2>/dev/null | head -1)
    exp_file=$(ls "$demo_dir"*.ref 2>/dev/null | head -1)

    if [ -z "$md" ]; then
        echo "  SKIP $dname (no .md file)"
        SKIP=$((SKIP+1))
        continue
    fi
    if [ -z "$exp_file" ] || [ ! -f "$exp_file" ]; then
        echo "  SKIP $dname (no .ref file)"
        SKIP=$((SKIP+1))
        continue
    fi

    expected=$(cat "$exp_file")
    actual=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$md" < /dev/null 2>/dev/null)
    label="$dname  ($(basename "$md"))"
    check "$label" "$expected" "$actual"
done

echo ""
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
# ⛔ A SWEEP THAT GRADED NOTHING IS NOT GREEN, AND A SKIPPED DEMO IS NOT A PASS (coo 2026-09-23, row instruments-polyglot-demos-
# expected-output-files-are-ref-only-expected-converts-to-ref). This line used to be `[ "$FAIL" -eq 0 ]`, so when the refs were
# renamed .expected -> .ref (CEO-1222) and this script still looked for .expected, it read PASS=0 FAIL=0 SKIP=10 and exited 0 --
# measured, one run before the readers switched. A demo without its ref cannot be graded (RULES.md THE KERNEL CONVENTION clause 1:
# every program carries a .ref), so it is counted red here, not skipped green.
[ $((PASS + FAIL)) -gt 0 ] || { echo "⛔ REFUSED(2): no demo was graded (PASS=0 FAIL=0 SKIP=$SKIP) -- a sweep that graded nothing is not green"; exit 2; }
[ "$SKIP" -eq 0 ] || { echo "⛔ $SKIP demo(s) have no .ref beside them and were not graded -- counted red, not skipped green"; exit 1; }
[ "$FAIL" -eq 0 ]
