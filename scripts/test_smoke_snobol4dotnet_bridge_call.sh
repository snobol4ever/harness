#!/usr/bin/env bash
# test_smoke_snobol4dotnet_bridge_call.sh — live FIFO smoke for S-2-bridge-4.
#
# Validates that the CALL + RETURN fire-points in
# ExecuteProgramDefinedFunction emit the correct wire records for
# a simple user-defined function.  Mirrors csn-bridge-b's probe_b.sno.
#
# Probe program:
#       DEFINE('SQR(N)')                         :(SQR_END)
# SQR   SQR = N * N                              :(RETURN)
# SQR_END
#       S = 'hello world'
#       S 'world' = 'there'
#       N = SQR(7)
# END
#
# Expected wire (7 records):
#   #0  VALUE  S    STRING(11)='hello world'   (Assign fire-point: S = ...)
#   #1  VALUE  S    STRING(11)='hello there'   (Assign fire-point: replacement)
#   #2  CALL   SQR                              (CALL fire-point at fn entry)
#   #3  VALUE  SQR  INTEGER(49)                 (Assign fire-point inside body)
#   #4  VALUE  SQR  INTEGER(49)                 (EmitValue for return slot)
#   #5  RETURN SQR  STRING(6)='RETURN'          (RETURN fire-point)
#   #6  VALUE  N    INTEGER(49)                 (Assign fire-point: N = SQR(...))
#   #7  END
#
# Note: records #3 and #4 both carry the return-variable value because
# bridge-2's Assign chokepoint fires when SQR = N*N executes (#3), and
# bridge-4's EmitValue fires the return-slot copy just before RETURN (#4).
# This mirrors the csn pattern: ASGNVV fires inside the function body, then
# DEFF20 emits the return-var value as a second VALUE before the RETURN record.
#
# Mon Apr 27 2026 — landed with S-2-bridge-4.

#
# (Moved here from snobol4dotnet's scripts/test_smoke_dot_bridge_call.sh, 2026-11-19, on Lon's word: the port's scripts live in harness. The port
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

TD="$(mktemp -d -t dot_bridge_call.XXXXXX)"
trap 'rm -rf "$TD"' EXIT

cat > "$TD/probe.sno" << 'EOF'
        DEFINE('SQR(N)')                         :(SQR_END)
SQR     SQR = N * N                              :(RETURN)
SQR_END
        S = 'hello world'
        S 'world' = 'there'
        N = SQR(7)
END
EOF

python3 "$READER" "$TD/ready.fifo" "$TD/go.fifo" "$TD/names.txt" \
    > "$TD/ctrl.out" 2> "$TD/ctrl.err" &
CTRL=$!

# Brief delay so the controller's mkfifo + open(O_RDONLY) is reached
# before the participant tries to open(O_WRONLY).
sleep 0.5

MONITOR_BIN=1 \
MONITOR_READY_PIPE="$TD/ready.fifo" \
MONITOR_GO_PIPE="$TD/go.fifo" \
MONITOR_NAMES_OUT="$TD/names.txt" \
    timeout 10 dotnet "$SNO4" -bf "$TD/probe.sno" > "$TD/dot.out" 2> "$TD/dot.err" < /dev/null
DOT_RC=$?

wait $CTRL 2>/dev/null

PASS=0; FAIL=0

# Check 1: dot exited cleanly
if [ $DOT_RC -eq 0 ]; then PASS=$((PASS+1)); else echo "FAIL dot exit=$DOT_RC"; cat "$TD/dot.err"; FAIL=$((FAIL+1)); fi

# Check 2: CALL record for SQR appears
if grep -qE "kind=CALL" "$TD/ctrl.err"; then
    PASS=$((PASS+1))
else echo "FAIL CALL record absent"; cat "$TD/ctrl.err"; FAIL=$((FAIL+1)); fi

# Check 3: RETURN record for SQR with type=RETURN appears
if grep -qE "kind=RETURN.*STRING.*RETURN|kind=RETURN.*RETURN" "$TD/ctrl.err"; then
    PASS=$((PASS+1))
else echo "FAIL RETURN record absent or wrong shape"; cat "$TD/ctrl.err"; FAIL=$((FAIL+1)); fi

# Check 4: VALUE record carrying INTEGER(49) appears at least once (return value)
if grep -qE "kind=VALUE.*INTEGER\(49\)" "$TD/ctrl.err"; then
    PASS=$((PASS+1))
else echo "FAIL VALUE INTEGER(49) absent"; cat "$TD/ctrl.err"; FAIL=$((FAIL+1)); fi

# Check 5: END record present
if grep -qE "kind=END" "$TD/ctrl.err"; then
    PASS=$((PASS+1))
else echo "FAIL END record absent"; FAIL=$((FAIL+1)); fi

# Check 6: CALL appears before RETURN (ordering)
CALL_LINE=$(grep -n "kind=CALL" "$TD/ctrl.err" | head -1 | cut -d: -f1)
RET_LINE=$(grep -n "kind=RETURN" "$TD/ctrl.err" | head -1 | cut -d: -f1)
if [ -n "$CALL_LINE" ] && [ -n "$RET_LINE" ] && [ "$CALL_LINE" -lt "$RET_LINE" ]; then
    PASS=$((PASS+1))
else echo "FAIL CALL (line $CALL_LINE) must precede RETURN (line $RET_LINE)"; FAIL=$((FAIL+1)); fi

# Check 7: names sidecar contains S, SQR, N
if [ -f "$TD/names.txt" ] && grep -qx "S" "$TD/names.txt" && grep -qx "SQR" "$TD/names.txt" && grep -qx "N" "$TD/names.txt"; then
    PASS=$((PASS+1))
else echo "FAIL names sidecar missing S/SQR/N"; cat "$TD/names.txt" 2>/dev/null; FAIL=$((FAIL+1)); fi

echo "PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "--- ctrl.err ---"
    cat "$TD/ctrl.err"
fi
[ $FAIL -eq 0 ]
