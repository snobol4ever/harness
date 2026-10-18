#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_global_no_nv_m3.sh — M3-ARENA-4: lock Icon mode-3 globals onto the [r9+k*16] GVA arena. (s230: base register is r9, the RC-5 claim — rbx is the heap frontier; the stale rbx grep was repaired this session, see d70fe6fc claimed-regs gate.)
#
# Behavioral output alone cannot catch an NV fallback (the NV path also returns the correct value), so this
# gate asserts THREE things for a globals program:
#   LOCK 1 (m4 emission)  : the --compile .s reaches the [rbx+...] gva form for the global and emits ZERO
#                           NV_GET_fn/NV_SET_fn on the global path. The m3 BINARY templates are the SAME
#                           medium-complete arms, so m4 proving the gva form implies m3 emits it too.
#   LOCK 2 (m3 engaged)   : with SCRIP_M3_GVA_TRACE=1, the mode-3 driver prints active=1 — proving the m3
#                           arena was allocated, gva_register ran, and g_gva_active was set BEFORE box build.
#                           If a regression drops the m3 arena, active=0 and this lock fails loudly.
#   LOCK 3 (m3==m4 value) : both modes print the expected result (write-then-read round-trip through the cell).
#
# Authors: LCherryholmes · Jeffrey Cooper M.D. · Claude Sonnet
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
SCRIP=./scrip
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PROG="$TMP/g.icn"
cat > "$PROG" <<'EOF'
global counter
procedure main()
  counter := 3;
  write(counter);
  counter := counter + 39;
  write(counter);
end
EOF
EXPECT=$'3\n42'
rc=0
echo "=== M3-ARENA-4 gate: Icon m3 globals on [r9+k*16] arena ==="

# LOCK 1 — m4 emission uses the gva arm, no NV on the global path.
S="$TMP/g.s"
"$SCRIP" --compile --target=x86 "$PROG" < /dev/null > "$S" 2>/dev/null
if grep -qE 'r9 \+ [0-9]+\].*# counter' "$S" && ! grep -qE 'NV_GET_fn|NV_SET_fn' "$S"; then
    echo "  PASS  LOCK 1: m4 globals via [r9+...] gva arena, zero NV on global path"
else
    echo "  FAIL  LOCK 1: m4 globals did not reach the gva arm (or NV present)"
    rc=1
fi

# LOCK 2 — m3 arena engaged (active=1).
TRACE="$(SCRIP_M3_GVA_TRACE=1 "$SCRIP" --run "$PROG" < /dev/null 2>&1 1>/dev/null)"
if grep -q 'active=1' <<< "$TRACE"; then
    echo "  PASS  LOCK 2: m3 gva arena engaged (active=1)"
else
    echo "  FAIL  LOCK 2: m3 did NOT engage the gva arena (NV fallback) — trace: $TRACE"
    rc=1
fi

# LOCK 3 — m3 and m4 both produce the expected value.
M3="$("$SCRIP" --run "$PROG" < /dev/null 2>/dev/null)"
gcc -no-pie "$S" -L out -lscrip_rt -lm -o "$TMP/g_m4" 2>/dev/null
M4="$(LD_LIBRARY_PATH=out "$TMP/g_m4" 2>/dev/null)"
if [ "$M3" = "$EXPECT" ] && [ "$M4" = "$EXPECT" ]; then
    echo "  PASS  LOCK 3: m3==m4==expected (3,42)"
else
    echo "  FAIL  LOCK 3: m3='$M3' m4='$M4' expected='$EXPECT'"
    rc=1
fi

[ "$rc" -eq 0 ] && echo "GATE PASS" || echo "GATE FAIL"
exit $rc
