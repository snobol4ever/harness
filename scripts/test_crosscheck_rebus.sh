#!/usr/bin/env bash
# test_crosscheck_rebus.sh — 3-mode crosscheck for REBUS (GOAL-LANG-REBUS)
#
# Runs the rebus test corpus through --run, --run, --run.
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

echo "=== Rebus 3-mode crosscheck ==="

T=$(mktemp /tmp/reb_XXXXXX.reb)
cat > "$T" << 'EOF'
function main()
  OUTPUT := "hello"
end
EOF
xcheck "output" "$T"

cat > "$T" << 'EOF'
function main()
  OUTPUT := 3 + 4
end
EOF
xcheck "arith" "$T"

cat > "$T" << 'EOF'
function main()
  x := 42
  OUTPUT := x
end
EOF
xcheck "var" "$T"

cat > "$T" << 'EOF'
function main()
  OUTPUT := "ab" || "cd"
end
EOF
xcheck "concat" "$T"

rm -f "$T"

# Rebus corpus files
RUNGS=$S4E/SCRIP/test/rebus
for f in "$RUNGS"/*.reb; do
    [ -f "$f" ] || continue
    ref="${f%.reb}.ref"
    xcheck "$(basename $f .reb)" "$f" "$ref"
done

echo ""
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
