#!/usr/bin/env bash
# test_gate_icn_monitor_a_cset_value_crosses_the_wire_as_icx_sends_it.sh -- AN ICON CSET VALUE NEVER BREAKS THE MONITOR WIRE
# (hq_icon 2026-09-25, crawl work under CEO-1270 / CEO-1272).
#
# SCRIP carries a cset as a DT_S descriptor whose length field is the sentinel 0xFFFFFFFF (IS_CSET_fn; the registry knows the
# real length). core.c's two wire encoders typed it MWT_STRING and sent that sentinel as the value length, so the controller
# read "insane value_len 4294967295" and monitor_run.sh --oracle REFUSED with THE WIRE BROKE on the first cset assignment --
# seven graded Arizona programs (cset, case, coerce, concord, mffsol, mindfa, scan_lib_driver) could not be bracketed at all.
# A cset now goes on the wire as icx sends one (monitor_icx.c: a T_Cset falls to MWT_UNKNOWN with no bytes): UNGRADED on
# both sides, never a torn header.
#
# THE WITNESS assigns a cset and then an integer: the bracket must run to its end (AGREE or UNGRADED, never a REFUSE), and the
# cset's step must read UNGRADED. Red on the encoder before this change (the wire breaks at the cset's VALUE).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_icn_monitor_a_cset_value_crosses_the_wire_as_icx_sends_it
[ -x "$HERE/../../SCRIP/scrip" ] || { echo "⛔ GATE REFUSE(2) [$G]: scrip not built"; exit 2; }
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"; S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
IM="${ICON_MON_ROOT:-$S4A/icon-mon}"
[ -x "$IM/bin/icont" ] && [ -x "$IM/bin/iconx" ] || { echo "⛔ GATE REFUSE(2) [$G]: the instrumented Icon fork is not built at $IM -- this gate cannot measure without icx"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/csetwire_gate.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
cat > "$T/csetwire.icn" <<'EOF'
procedure main()
   local x, n;
   x := 'a1b2c3';
   n := *x;
   write(n);
end
EOF
out="$(cd "$T" && timeout -k 5 300 bash "$HERE/monitor_run.sh" csetwire.icn --oracle 2>&1)"; rc=$?
line="$(printf '%s\n' "$out" | grep -aE '^\[monitor_run\] (AGREE|DIVERGE|UNGRADED)|REFUSE' | tail -1 | cut -c1-200)"
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qaE '^\[monitor_run\] UNGRADED=[1-9]' && ! printf '%s\n' "$out" | grep -qa 'WIRE BROKE'; then
    echo "  $line"
    echo "✅ GATE PASS [$G]: a cset assignment crosses the wire untyped, as icx sends it, and the bracket runs to its end"; exit 0
fi
echo "  rc=$rc $line"
echo "⛔ GATE FAIL [$G]: the cset witness did not run to its end with the cset UNGRADED"; exit 1
