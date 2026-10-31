#!/usr/bin/env bash
# test_smoke_rebus.sh — per-frontend smoke for Rebus  (FI-9)
# Gate: exits 0 in < 2s on a clean build.
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet 4.6  DATE: 2026-04-14
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${HERE}/../../SCRIP/scrip"
. "$HERE/lib_smoke_honest.sh" || { echo "SMOKE REFUSE(2): lib_smoke_honest.sh unloadable"; exit 2; }   # CEO-2081: a timed-out step prints TIMEOUT; under overload the smoke refuses
PASS=0; FAIL=0

rebus() {
    local label="$1" expected="$2"
    local tmp; tmp=$(mktemp /tmp/reb_XXXXXX.reb)
    cat > "$tmp"
    local actual; actual=$(smoke_t -k 5 8 "$SCRIP" --run "$tmp" 2>/dev/null)
    rm -f "$tmp"
    if [ "$actual" = "$expected" ]; then echo "  PASS $label"; PASS=$((PASS+1))
    else echo "  FAIL $label (got: $(echo "$actual"|head -1))"; FAIL=$((FAIL+1)); fi
}

echo "=== Rebus smoke ==="

rebus "output_str" "hello" << 'EOF'
function main()
  OUTPUT := "hello"
end
EOF

rebus "arith" "7" << 'EOF'
function main()
  OUTPUT := 3 + 4
end
EOF

rebus "var" "42" << 'EOF'
function main()
  x := 42
  OUTPUT := x
end
EOF

rebus "concat" "abcd" << 'EOF'
function main()
  OUTPUT := "ab" || "cd"
end
EOF

echo ""; echo "PASS=$PASS FAIL=$FAIL"
# ⛔ ONE LEADERBOARD (RULES.md FACT RULE, Lon 2026-09-03 ~16:05: "any run of a test suite by any
# session will update the ONE LEADERBOARD"). This records the board line printed just above into
# .github/SCORE.md -- it RUNS NOTHING, it only writes down what this script already measured.
# ⛔ NON-FATAL BY DESIGN: a bookkeeping failure must never turn a real measurement into a red board,
# because a gate that goes red for a reason unrelated to the code is a gate people route around. It
# warns and names the unrecorded row instead; it has no silent path.
smoke_refuse_if_loaded   # CEO-2081: a timeout under load over 2x cores refuses rc 2 before any verdict or score write
python3 "$HERE/util_score_row.py" write --lang rebus --column floor --modes m3 \
    --measurer "${S4E_SEAT:-}" --text "smoke PASS=$PASS FAIL=$FAIL (\`test_smoke_rebus.sh\`)" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
[ "$FAIL" -eq 0 ]
