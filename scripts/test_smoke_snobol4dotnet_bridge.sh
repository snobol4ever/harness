#!/usr/bin/env bash
# test_smoke_snobol4dotnet_bridge.sh — smoke gate for S-2-bridge-1 (dormant bridge).
#
# Confirms:
#   1. snobol4dotnet runs the beauty demo, with MonitorIpc.cs present, and prints beauty's ref (sbl -bf's answer) byte for byte.
#   2. Setting MONITOR_BIN=1 alone (FIFOs absent) produces byte-identical output to the no-env-var run — init fails silently, all
#      entry points stay no-op.
#   3. Setting MONITOR_READY_PIPE / MONITOR_GO_PIPE to non-existent paths produces byte-identical output too — open() fails, init
#      stays !_initOk, entry points stay no-op.
#
# The end-to-end "bridge actually emits records" gate lands with S-2-bridge-2 (the first fire-point); this script is the dormancy
# gate that should ride along forever.
#
# Sat Apr 27 2026 — landed with S-2-bridge-1.
#
# (Moved here from snobol4dotnet's scripts/test_smoke_dot_bridge.sh, 2026-11-19, on Lon's word: the port's scripts live in harness. The
# port is the clone S4E_DOTNET_ROOT names, default /home/claude_dotnet, as run_snobol4dotnet.sh reads it; a skip is now REFUSE(2), never
# a pass. Beauty is the one program demos/snobol4/beauty/beauty.sno of the corpus, run on beauty.in with SNOLIB naming the corpus
# include folder, as the demos suite runs it; the *_driver.sno files the first text looked for are gone from the corpus, so it skipped.)
# Exit: 0 every check passes, 1 a check fails, 2 could not measure (no dotnet, no build, no beauty).

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_paths.sh"

SNO4_REPO="${SNO4_REPO:-${S4E_DOTNET_ROOT:-/home/claude_dotnet}}"
SNO4="${SNO4:-$SNO4_REPO/Snobol4/bin/Release/net10.0/Snobol4.dll}"
BEAUTY="${BEAUTY:-$S4E_CORPUS/demos/snobol4/beauty}"
export SNOLIB="${SNOLIB:-$S4E_CORPUS/include}"

# Locate dotnet.  apt installs to /usr/bin; legacy doc says /usr/local/dotnet10.
if command -v dotnet >/dev/null 2>&1; then
    : # OK
elif [ -x /usr/local/dotnet10/dotnet ]; then
    export PATH="/usr/local/dotnet10:$PATH"
else
    echo "REFUSE(2): dotnet not on PATH"; exit 2
fi

if [ ! -f "$SNO4" ]; then
    echo "REFUSE(2): $SNO4 not built — run dotnet build first"; exit 2
fi
for f in beauty.sno beauty.in beauty.out; do
    [ -f "$BEAUTY/$f" ] || { echo "REFUSE(2): no $f in $BEAUTY"; exit 2; }
done

TD="$(mktemp -d -t snobol4dotnet_bridge.XXXXXX)"
trap 'rm -rf "$TD"' EXIT
cp -r "$BEAUTY/." "$TD/"
cd "$TD"

PASS=0; FAIL=0

# --- check 1: no env vars (baseline), and it is beauty's ref ----------------
timeout -k 5 300 dotnet "$SNO4" -bf beauty.sno < beauty.in > baseline.out 2> baseline.err
RC=$?
if [ $RC -eq 0 ] && cmp -s baseline.out beauty.out; then PASS=$((PASS+1)); else echo "FAIL baseline rc=$RC or output differs from beauty.out"; FAIL=$((FAIL+1)); fi

# --- check 2: MONITOR_BIN=1 only (FIFOs absent) ----------------------------
MONITOR_BIN=1 timeout -k 5 300 dotnet "$SNO4" -bf beauty.sno < beauty.in > bin_only.out 2> bin_only.err
RC=$?
if [ $RC -eq 0 ]; then PASS=$((PASS+1)); else echo "FAIL bin-only rc=$RC"; FAIL=$((FAIL+1)); fi

# --- check 3: bad pipe paths -----------------------------------------------
MONITOR_BIN=1 MONITOR_READY_PIPE="$TD/nonexist_ready" MONITOR_GO_PIPE="$TD/nonexist_go" \
    timeout -k 5 300 dotnet "$SNO4" -bf beauty.sno < beauty.in > bad.out 2> bad.err
RC=$?
if [ $RC -eq 0 ]; then PASS=$((PASS+1)); else echo "FAIL bad-paths rc=$RC"; FAIL=$((FAIL+1)); fi

# --- check 4: byte-identical outputs ---------------------------------------
if cmp -s baseline.out bin_only.out && cmp -s baseline.err bin_only.err
then PASS=$((PASS+1)); else echo "FAIL bin-only diverges from baseline"; FAIL=$((FAIL+1)); fi

if cmp -s baseline.out bad.out && cmp -s baseline.err bad.err
then PASS=$((PASS+1)); else echo "FAIL bad-paths diverges from baseline"; FAIL=$((FAIL+1)); fi

echo "PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ]
