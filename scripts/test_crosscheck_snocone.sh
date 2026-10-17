#!/usr/bin/env bash
# test_crosscheck_snocone.sh — 3-mode crosscheck for SNOCONE (GOAL-SNOCONE-100)
#
# Runs the snocone test corpus through --run, --run, --run.
# Run on every major push. Mode-consistency check, not regression.
# If .ref present alongside test file: diffs vs oracle too.
# Exits 0 only if all three modes agree on every test.
#
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet 4.6  DATE: 2026-04-14
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${HERE}/../../SCRIP/scrip"
TIMEOUT=30
PASS=0; FAIL=0; SKIP=0

xcheck() {
    local label="$1" file="$2" ref="${3:-}"
    if [ ! -f "$file" ]; then echo "  SKIP $label (no file)"; SKIP=$((SKIP+1)); return; fi
    local ir sm run_out
    ir=$(timeout -k 5 $TIMEOUT "$SCRIP" --run  "$file" </dev/null 2>/dev/null)
    sm=$(timeout -k 5 $TIMEOUT "$SCRIP" --run  "$file" </dev/null 2>/dev/null)
    run_out=$(timeout -k 5 $TIMEOUT "$SCRIP" --run "$file" </dev/null 2>/dev/null)
    local ok=1
    if [ -n "$ref" ] && [ -f "$ref" ]; then
        local exp; exp=$(cat "$ref")
        [ "$ir"  != "$exp" ] && { echo "  FAIL $label --run  vs oracle"; diff <(echo "$exp") <(echo "$ir")  | head -5 | sed 's/^/    /'; ok=0; }
        [ "$sm"  != "$exp" ] && { echo "  FAIL $label --run  vs oracle"; diff <(echo "$exp") <(echo "$sm")  | head -5 | sed 's/^/    /'; ok=0; }
        [ "$run_out" != "$exp" ] && { echo "  FAIL $label --run vs oracle"; diff <(echo "$exp") <(echo "$run_out") | head -5 | sed 's/^/    /'; ok=0; }
    else
        [ "$sm"  != "$ir" ] && { echo "  FAIL $label --run  vs --run";  diff <(echo "$ir") <(echo "$sm")  | head -5 | sed 's/^/    /'; ok=0; }
        [ "$run_out" != "$ir" ] && { echo "  FAIL $label --run vs --run";  diff <(echo "$ir") <(echo "$run_out") | head -5 | sed 's/^/    /'; ok=0; }
    fi
    if [ "$ok" -eq 1 ]; then echo "  PASS $label"; PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
}

echo "=== Snocone 3-mode crosscheck ==="

T=$(mktemp /tmp/sc_XXXXXX.sc)
cat > "$T" << 'EOF'
OUTPUT = "hello"
EOF
xcheck "output" "$T"

cat > "$T" << 'EOF'
OUTPUT = 2 + 3
EOF
xcheck "arith" "$T"

cat > "$T" << 'EOF'
procedure Double(n) {
    Double = n + n; return;
}
OUTPUT = Double(21)
EOF
xcheck "procedure" "$T"

cat > "$T" << 'EOF'
i = 1;
while (LE(i, 3)) { OUTPUT = i; i = i + 1; }
EOF
xcheck "while" "$T"

rm -f "$T"

# Beauty-sc subsystems
# ⛔⭐ demo/ -> demos/ (corpus re-grid). This path had been dead since the rename and the loop
# below DROPPED ALL FOUR beauty subsystems SILENTLY -- `[ -f ] && xcheck` with no else, not even a SKIP
# count. The gate printed "PASS=4 FAIL=0 SKIP=0" and exited 0 while running half the cases it names.
# ⭐ A silent drop is worse than a skip and far worse than a failure: the summary line is not merely
# incomplete, it is CONFIDENT -- SKIP=0 positively asserts that nothing was left out. Counting the miss is
# what makes the denominator honest, so the else branch below is the real fix and the path is only the cause.
BEAUTY=${CORPUS:-$S4E/corpus}/demos/snocone/beauty/test
for subsys in assign fence global arith; do
    f="$BEAUTY/test_$subsys.sc"
    ref="$BEAUTY/test_$subsys.ref"
    if [ -f "$f" ]; then xcheck "beauty_$subsys" "$f" "$ref"
    else echo "  SKIP beauty_$subsys (missing: $f)"; SKIP=$((SKIP+1)); fi
done

echo ""
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
