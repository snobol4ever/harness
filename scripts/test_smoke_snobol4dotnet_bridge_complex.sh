#!/usr/bin/env bash
# test_smoke_snobol4dotnet_bridge_complex.sh — full 5-LHS-form coverage smoke for
# S-2-bridge-3.
#
# Validates that the assignment chokepoint VALUE fire-point in
# Executive.Assign covers all five LHS forms found in csnobol4's
# probe_complex.sno (canonical reference: SN-26-bridge-coverage-a):
#
#   1.  plain scalar  (X = ...)
#   2.  pat . X       (.-capture commit)
#   3.  pat $ X       (immediate value-assignment in match)
#   4.  a<i,j> = ...  (array element store)
#   5.  d<'k'> = ...  (table slot store)
#
# (User-fn pattern interactions like 'pat . *fn(arg)' are deferred to
# S-2-bridge-4.  This script tests the structural assignment chokepoint
# only — same shape as csn-bridge-a + csn-bridge-c minus the CALL/RETURN
# records around *fn invocations.)
#
# Discovery (2026-04-27): snobol4dotnet's pattern-match commit walks
# BetaStack and calls Executive.Assign() per nameListEntry — i.e. it
# routes .-capture and $-capture through the same chokepoint as plain
# = stores.  So S-2-bridge-2's single fire-point already covers all
# csn fire sites (ASGNVV + NMD4 + ENMI3 + ATP).  This gate makes the
# discovery permanent.
#
# Sat Apr 27 2026 — landed with S-2-bridge-3.

#
# (Moved here from snobol4dotnet's scripts/test_smoke_dot_bridge_complex.sh, 2026-11-19, on Lon's word: the port's scripts live in harness. The port
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

TD="$(mktemp -d -t dot_bridge_complex.XXXXXX)"
trap 'rm -rf "$TD"' EXIT

cat > "$TD/probe.sno" << 'EOF'
            myname = 'unset'
            S = 'AXBYC'
            S ANY('AB') . dotcap
            S2 = 'AXBYC'
            S2 ANY('AB') $ dolcap
            a = ARRAY('1:3')
            a<2> = 'array_elem'
            d = TABLE()
            d<'mykey'> = 'tbl_elem'
END
EOF

python3 "$READER" "$TD/ready.fifo" "$TD/go.fifo" "$TD/names.txt" \
    > "$TD/ctrl.out" 2> "$TD/ctrl.err" &
CTRL=$!
sleep 0.5

MONITOR_BIN=1 \
MONITOR_READY_PIPE="$TD/ready.fifo" \
MONITOR_GO_PIPE="$TD/go.fifo" \
MONITOR_NAMES_OUT="$TD/names.txt" \
    timeout 10 dotnet "$SNO4" -bf "$TD/probe.sno" > "$TD/dot.out" 2> "$TD/dot.err"
DOT_RC=$?
wait $CTRL 2>/dev/null

PASS=0; FAIL=0

# Check 1: clean exit
if [ $DOT_RC -eq 0 ]; then PASS=$((PASS+1)); else echo "FAIL exit=$DOT_RC"; FAIL=$((FAIL+1)); fi

# Check 2: exactly 20 records (10 LABEL + 9 VALUE + 1 END)
# 10 statements (9 assignments + END), each preceded by a LABEL.
N=$(grep -cE "kind=" "$TD/ctrl.err" || true)
if [ "$N" = "20" ]; then PASS=$((PASS+1)); else echo "FAIL count: $N != 20"; cat "$TD/ctrl.err"; FAIL=$((FAIL+1)); fi

# Check 3: scalar plain assignment
grep -qE "VALUE name_id=0 STRING\(5\)=b['\"]unset['\"]" "$TD/ctrl.err" \
    && PASS=$((PASS+1)) || { echo "FAIL plain scalar"; FAIL=$((FAIL+1)); }

# Check 4: .-capture
grep -qE "VALUE name_id=2 STRING\(1\)=b['\"]A['\"]" "$TD/ctrl.err" \
    && PASS=$((PASS+1)) || { echo "FAIL .-capture"; FAIL=$((FAIL+1)); }

# Check 5: $-capture
grep -qE "VALUE name_id=4 STRING\(1\)=b['\"]A['\"]" "$TD/ctrl.err" \
    && PASS=$((PASS+1)) || { echo "FAIL \$-capture"; FAIL=$((FAIL+1)); }

# Check 6: array creation (type code ARRAY)
grep -qE "VALUE name_id=5 ARRAY" "$TD/ctrl.err" \
    && PASS=$((PASS+1)) || { echo "FAIL array creation"; FAIL=$((FAIL+1)); }

# Check 7: array element store routes to the underlying array name 'a' (not <lval>).
# S-2-bridge-7-lval landed Mon Apr 28 2026: aggregate-element stores now emit the
# collection's symbol, so a<2>='array_elem' shows name_id=5 (= 'a', shared with
# the array creation record above).
grep -qE "VALUE name_id=5 STRING\(10\)=b['\"]array_elem['\"]" "$TD/ctrl.err" \
    && PASS=$((PASS+1)) || { echo "FAIL array element name attribution"; FAIL=$((FAIL+1)); }

# Check 8: table slot store routes to the underlying table name 'd' (not <lval>).
# Same rationale as Check 7.
grep -qE "VALUE name_id=6 STRING\(8\)=b['\"]tbl_elem['\"]" "$TD/ctrl.err" \
    && PASS=$((PASS+1)) || { echo "FAIL table slot name attribution"; FAIL=$((FAIL+1)); }

# Check 9: names sidecar has exactly 7 names (no <lval> sentinel since
# every aggregate-element store resolves to its collection's symbol).
LINE_COUNT=$(wc -l < "$TD/names.txt" 2>/dev/null || echo 0)
if [ "$LINE_COUNT" = "7" ] && ! grep -q "<lval>" "$TD/names.txt"; then
    PASS=$((PASS+1))
else
    echo "FAIL names sidecar: $LINE_COUNT lines, contains <lval>=$(grep -c '<lval>' "$TD/names.txt")"
    cat -n "$TD/names.txt"
    FAIL=$((FAIL+1))
fi

echo "PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ]
