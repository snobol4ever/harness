#!/usr/bin/env bash
# test_smoke_snobol4dotnet_bridge_value.sh — live FIFO smoke for S-2-bridge-2.
#
# Validates the assignment chokepoint VALUE fire-point in
# Executive.Assign emits exactly:
#
#   #0  kind=LABEL name_id=0xffffffff INTEGER(1)             (stmt 1 entry)
#   #1  kind=VALUE name_id=0 STRING(5)=b'hello'              (S = 'hello')
#   #2  kind=LABEL name_id=0xffffffff INTEGER(2)             (END entry)
#   #3  kind=END   name_id=0xffffffff NULL(empty)
#
# for the canonical hello probe:
#
#       S = 'hello'
#   END
#
# Names sidecar contains exactly "S\n" (no BOM, LF terminator) at id=0 —
# byte-identical to what csn's lvalue_name_id would intern.  Note: this
# names file is now WRITTEN by read_one_wire.py from MWK_NAME_DEF wire
# records (SN-26-bridge-coverage-e); the runtime no longer writes it.
#
# Sat Apr 27 2026 — landed with S-2-bridge-2.
# Updated 2026-04-27 — LABEL records added per SN-26-bridge-coverage-f.

#
# (Moved here from snobol4dotnet's scripts/test_smoke_dot_bridge_value.sh, 2026-11-19, on Lon's word: the port's scripts live in harness. The port
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

TD="$(mktemp -d -t dot_bridge_value.XXXXXX)"
trap 'rm -rf "$TD"' EXIT

cat > "$TD/probe.sno" << 'EOF'
            S = 'hello'
END
EOF

python3 "$READER" "$TD/ready.fifo" "$TD/go.fifo" "$TD/names.txt" \
    > "$TD/ctrl.out" 2> "$TD/ctrl.err" &
CTRL=$!

# Brief delay so the controller's mkfifo + open(O_RDONLY) is reached
# before the participant tries to open(O_WRONLY).  FIFO semantics
# require a reader to be present.
sleep 0.5

MONITOR_BIN=1 \
MONITOR_READY_PIPE="$TD/ready.fifo" \
MONITOR_GO_PIPE="$TD/go.fifo" \
MONITOR_NAMES_OUT="$TD/names.txt" \
    timeout 10 dotnet "$SNO4" -b "$TD/probe.sno" > "$TD/dot.out" 2> "$TD/dot.err"
DOT_RC=$?

wait $CTRL 2>/dev/null

PASS=0; FAIL=0

# Check 1: dot exited cleanly
if [ $DOT_RC -eq 0 ]; then PASS=$((PASS+1)); else echo "FAIL dot exit=$DOT_RC"; FAIL=$((FAIL+1)); fi

# Check 2: exactly 4 records (LABEL VALUE LABEL END)
N=$(grep -cE "kind=" "$TD/ctrl.err" || true)
if [ "$N" = "4" ]; then PASS=$((PASS+1)); else echo "FAIL record count: got $N expected 4"; cat "$TD/ctrl.err"; FAIL=$((FAIL+1)); fi

# Check 3: VALUE record carries name_id=0 STRING(5)='hello' (now at #1, after LABEL(1))
if grep -qE "#0+1 kind=VALUE name_id=0 STRING\(5\)=b['\"]hello['\"]" "$TD/ctrl.err"; then
    PASS=$((PASS+1))
else echo "FAIL VALUE record shape"; cat "$TD/ctrl.err"; FAIL=$((FAIL+1)); fi

# Check 4: END record present
if grep -qE "kind=END" "$TD/ctrl.err"; then
    PASS=$((PASS+1))
else echo "FAIL END record absent"; FAIL=$((FAIL+1)); fi

# Check 5: names sidecar is exactly "S\n" — no BOM, LF terminator
EXPECTED_HEX="53 0a"
ACTUAL_HEX=$(od -An -t x1 "$TD/names.txt" 2>/dev/null | tr -s ' ' | sed 's/^ //' | tr -d '\n' | sed 's/  *$//')
if [ "$ACTUAL_HEX" = "$EXPECTED_HEX" ]; then
    PASS=$((PASS+1))
else echo "FAIL names sidecar hex: got '$ACTUAL_HEX' expected '$EXPECTED_HEX'"; FAIL=$((FAIL+1)); fi

echo "PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ]
