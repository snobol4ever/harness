#!/usr/bin/env bash
# test_smoke_snobol4dotnet_bridge_stno.sh — S-2-bridge-7: verify dot's LABEL stno
# matches SPITBOL's &STNO convention (blank lines consume an stno slot).
#
# Pre-fix: dot emitted stnos 1,2,3,4 for a 5-line program with one blank
# line; spl emitted 1,2,4,5 (skipping the blank).  Goal: dot must skip
# blank-line slots too so the 3-way controller sees byte-identical
# LABEL records.
#
# S-2-bridge-7, Mon Apr 28 2026.

#
# (Moved here from snobol4dotnet's scripts/test_smoke_dot_bridge_stno.sh, 2026-11-19, on Lon's word: the port's scripts live in harness. The port
# is the clone S4E_DOTNET_ROOT names, default /home/claude_dotnet, as run_snobol4dotnet.sh reads it; a skip is now REFUSE(2), never a pass.)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SNO4_REPO="${SNO4_REPO:-${S4E_DOTNET_ROOT:-/home/claude_dotnet}}"
SNO4="${SNO4:-$SNO4_REPO/Snobol4/bin/Release/net10.0/Snobol4.dll}"
READER="${READER:-$HERE/monitor/read_one_wire.py}"

if ! command -v dotnet >/dev/null 2>&1; then
    if [ -x /usr/local/dotnet10/dotnet ]; then export PATH="/usr/local/dotnet10:$PATH"
    else echo "REFUSE(2): dotnet missing"; exit 2; fi
fi
if [ ! -f "$SNO4" ]; then echo "REFUSE(2): $SNO4 not built"; exit 2; fi
if [ ! -f "$READER" ]; then echo "REFUSE(2): $READER missing"; exit 2; fi

TD="$(mktemp -d -t dot_bridge_stno.XXXXXX)"
trap 'rm -rf "$TD"' EXIT

cat > "$TD/probe.sno" << 'EOF'
                  a = 1
                  b = 2

                  c = 3
END
EOF

python3 "$READER" "$TD/ready.fifo" "$TD/go.fifo" "$TD/names.txt" \
    > "$TD/ctrl.out" 2> "$TD/ctrl.err" &
CTRL=$!
sleep 0.5

MONITOR_BIN=1 \
MONITOR_READY_PIPE="$TD/ready.fifo" \
MONITOR_GO_PIPE="$TD/go.fifo" \
    timeout 10 dotnet "$SNO4" -bf "$TD/probe.sno" > "$TD/dot.out" 2> "$TD/dot.err"
DOT_RC=$?
wait $CTRL 2>/dev/null

PASS=0; FAIL=0

# Check 1: clean exit
if [ $DOT_RC -eq 0 ]; then PASS=$((PASS+1)); else echo "FAIL exit=$DOT_RC"; cat "$TD/dot.err"; FAIL=$((FAIL+1)); fi

# Check 2: stno=1 fires (a=1 line)
grep -qE "LABEL.*INTEGER\(1\)$" "$TD/ctrl.err" \
    && PASS=$((PASS+1)) || { echo "FAIL no LABEL=1"; FAIL=$((FAIL+1)); }

# Check 3: stno=2 fires (b=2 line)
grep -qE "LABEL.*INTEGER\(2\)$" "$TD/ctrl.err" \
    && PASS=$((PASS+1)) || { echo "FAIL no LABEL=2"; FAIL=$((FAIL+1)); }

# Check 4: stno=3 does NOT fire (it belongs to the blank line)
if grep -qE "LABEL.*INTEGER\(3\)$" "$TD/ctrl.err"; then
    echo "FAIL: LABEL=3 fired (blank line was counted as executable!)"
    cat "$TD/ctrl.err"
    FAIL=$((FAIL+1))
else
    PASS=$((PASS+1))
fi

# Check 5: stno=4 fires (c=3 line — blank line consumed slot 3)
grep -qE "LABEL.*INTEGER\(4\)$" "$TD/ctrl.err" \
    && PASS=$((PASS+1)) || { echo "FAIL no LABEL=4 (blank-line offset broken)"; FAIL=$((FAIL+1)); }

# Check 6: stno=5 fires (END line)
grep -qE "LABEL.*INTEGER\(5\)$" "$TD/ctrl.err" \
    && PASS=$((PASS+1)) || { echo "FAIL no LABEL=5 (END)"; FAIL=$((FAIL+1)); }

echo "PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ]
