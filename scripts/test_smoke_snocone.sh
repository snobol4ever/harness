#!/usr/bin/env bash
# test_smoke_snocone.sh — per-frontend smoke for Snocone  (FI-9)
# Gate: exits 0 in < 2s on a clean build.
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet 4.6  DATE: 2026-04-14
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${HERE}/../../SCRIP/scrip"
PASS=0; FAIL=0

snocone() {
    local label="$1" expected="$2"
    local tmp; tmp=$(mktemp /tmp/sc_XXXXXX.sc)
    cat > "$tmp"
    local actual; actual=$(timeout -k 5 8 "$SCRIP" --run "$tmp" 2>/dev/null)
    rm -f "$tmp"
    if [ "$actual" = "$expected" ]; then echo "  PASS $label"; PASS=$((PASS+1))
    else echo "  FAIL $label (got: $(echo "$actual"|head -1))"; FAIL=$((FAIL+1)); fi
}

echo "=== Snocone smoke ==="

snocone "output" "hello" << 'EOF'
OUTPUT = "hello";
EOF

snocone "arith" "5" << 'EOF'
OUTPUT = 2 + 3;
EOF

snocone "procedure" "42" << 'EOF'
function Double(n) {
    Double = n + n; return;
}
OUTPUT = Double(21);
EOF

snocone "if_eq" "yes" << 'EOF'
if (EQ(2 + 2, 4)) { OUTPUT = "yes"; } else { OUTPUT = "no"; }
EOF

snocone "while" "$(printf '1\n2\n3')" << 'EOF'
i = 1;
while (LE(i, 3)) { OUTPUT = i; i = i + 1; }
EOF

# CORE ARM (ceo CEO-1952; Lon 2026-10-24: "Let's get better smoke tests for SNOBOL4, it keeps missing a lot."): the hand cases missed two Snocone core
# crashes that day (521c5afcd). The arm grades the Snocone PARTITION core in BOTH modes through the one extraction authority, HARD in both, progress off.
CT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../corpus/tests/snocone"
COUT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && S4E_PROGRESS_OFF=1 SUITE_LIST_ALL=1 S4E_ONE_RUNNER_OVERRIDE="test_smoke_snocone.sh core arm (CEO-1952)" timeout -k 5 300 python3 ../harness/scripts/corpus_suite_harness.py run "$CT/ALL.sc" "$CT/ALL.ref" --lang snocone --modes m3,m4 --partition core 2>&1)"
CB="$(printf '%s\n' "$COUT" | grep -m1 '^SUITE_BOARD')"
[ -n "$CB" ] || { printf '%s\n' "$COUT" | tail -3 | sed 's/^/  /'; echo "core arm REFUSE(2): the harness printed no SUITE_BOARD line"; exit 2; }
cv() { printf '%s\n' "$CB" | grep -oE " $1=[0-9]+" | head -1 | cut -d= -f2; }
CN3=$(cv m3_n); CP3=$(cv m3_pass); CN4=$(cv m4_n); CP4=$(cv m4_pass); CF3=$((CN3-CP3)); CF4=$((CN4-CP4))
printf '%s\n' "$COUT" | grep -E '^ +(FAIL|CRASH|HANG|UNPROVEN) m[34] ' | sed 's/^ */  CORE-/'
echo ""; echo "core arm (Snocone core, $CN4 entries): m3 PASS=$CP3 FAIL=$CF3  m4 PASS=$CP4 FAIL=$CF4   (HARD, both modes)"
echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ] && [ "$CF3" -eq 0 ] && [ "$CF4" -eq 0 ]
