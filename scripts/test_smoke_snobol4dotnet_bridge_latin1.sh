#!/usr/bin/env bash
# test_smoke_snobol4dotnet_bridge_latin1.sh — S-2-bridge-7: verify StringVar bytes
# on the monitor wire use Latin-1 (ISO-8859-1), not UTF-8.
#
# SNOBOL4 strings are 8-bit byte buffers.  &LCASE / &UCASE complement sets
# contain chars 0x80–0xFF (Latin-1 supplement).  The assignment chokepoint
# in MonitorIpc.ClassifyValue must emit those bytes verbatim.
#
# Failure signature (pre-fix): STRING(2)=b'\x80\x81' arrives as
# STRING(4)=b'\xc2\x80\xc2\x81' (each byte UTF-8-double-encoded).
#
# S-2-bridge-7, Mon Apr 28 2026.

#
# (Moved here from snobol4dotnet's scripts/test_smoke_dot_bridge_latin1.sh, 2026-11-19, on Lon's word: the port's scripts live in harness. The port
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

TD="$(mktemp -d -t dot_bridge_latin1.XXXXXX)"
trap 'rm -rf "$TD"' EXIT

# Build a 2-byte string from the first two chars of &LCASE supplement.
# &LCASE on SPITBOL/csn is 'abcdefghijklmnopqrstuvwxyz' followed by the
# 26-char Latin-1 complement.  We just assign a known 2-byte Latin-1 string
# by taking SIZE chars from &LCASE beyond position 26.
#
# Simpler: assign a string whose chars are chr(128) and chr(129) directly,
# using CHAR() built-in.
cat > "$TD/probe.sno" << 'EOF'
            S = CHAR(128) CHAR(129)
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

# Check 2: STRING(2) — exactly 2 bytes, not 4 (which is the UTF-8 double-encoded form)
# read_one_wire.py prints value as Python bytes repr, e.g. STRING(2)=b'\x80\x81'
if grep -qE "VALUE.*STRING\(2\)" "$TD/ctrl.err"; then
    PASS=$((PASS+1))
else
    echo "FAIL: did not find STRING(2) on wire (UTF-8 double-encode bug?)"
    cat "$TD/ctrl.err"
    FAIL=$((FAIL+1))
fi

# Check 3: the 2 raw bytes are 0x80 and 0x81
if grep -qE "VALUE.*STRING\(2\)=b'\\\\x80\\\\x81'" "$TD/ctrl.err"; then
    PASS=$((PASS+1))
else
    echo "FAIL: bytes are not \\x80\\x81"
    grep -E "VALUE" "$TD/ctrl.err" || true
    FAIL=$((FAIL+1))
fi

echo "PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ]
