#!/usr/bin/env bash
# test_gate_m1_self_host_fixed_point.sh — MILESTONE 1's DEFINING PROPERTY, as a gate that can say NO.
#
# ⛔ WHY THIS DID NOT EXIST UNTIL 2026-08-22, WHICH IS THE WHOLE POINT: M1 is "beauty self-host reaches its
# fixed point -- output byte-identical to the input" (Lon s117: the checked-in file is its own oracle).
# `grep -rln '40971\|6f1671c0' ../harness/scripts/*.sh` returned NOTHING. test_gate_sn7_beauty_self_host.sh is named
# for it but iterates 34 beauty_suite *_driver.sno witnesses -- a real check, and not this one. So the
# milestone the project is measured by had NO gate, and that is exactly how both of these went unnoticed:
#   * RUNG C-0 (m3 self-host emitting 278 bytes) sat un-caught until a human bisected by hand;
#   * the -O1/-O2 breakage sat un-caught because nobody ran the arm and nothing would have told them.
# A milestone with no gate is a milestone nobody is defending.
#
# ⛔ RT_OPT IS PART OF THE VERDICT. This gate grades whatever RT_OPT built out/libscrip_rt.so, and prints
# which configuration that was. A correctness verdict that does not name its configuration axis is a
# verdict about one arm reported as though it were about the product (hq_C, s258, learned the hard way).
#
# usage: bash ../harness/scripts/test_gate_m1_self_host_fixed_point.sh [m3|m4|both]     exit 0 = the fixed point holds
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PROBE="$S4E/.github/probes/m1-bisect/check_m1_fixedpoint.sh"
ARM="${1:-both}"
case "$ARM" in m3|m4|both) ;; *) echo "⛔ GATE UNPROVEN(2): unrecognized ARM '$ARM' — expected m3, m4, or both"; exit 2;; esac
if [ ! -x "$S4E/SCRIP/scrip" ]; then echo "⛔ FAIL: scrip is not built. A missing binary is a FAILURE, not a skip —"; echo "   a gate that goes green when its subject is absent is the false-green class this gate exists to end."; exit 1; fi
[ -f "$PROBE" ] || { echo "⛔ FAIL: the M1 probe is missing at $PROBE"; exit 1; }
echo "=== MILESTONE 1 — BEAUTY SELF-HOST FIXED POINT ==="
printf 'built with : %s\n' "$(readlink "$S4E/SCRIP/out/libscrip_rt.so" 2>/dev/null || echo 'out/libscrip_rt.so (untagged)')"
bash "$PROBE" "$ARM"; rc=$?
if [ "$rc" -eq 0 ]; then echo "M1 GATE: PASS"; else echo "M1 GATE: ⛔ FAIL — Milestone 1 does not hold for this build configuration."; fi
exit $rc
