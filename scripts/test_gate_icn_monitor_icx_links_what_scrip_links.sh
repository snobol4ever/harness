#!/usr/bin/env bash
# test_gate_icn_monitor_icx_links_what_scrip_links.sh -- THE ICON ORACLE PARTICIPANT CAN BRACKET A PROGRAM THAT LINKS A LIBRARY
# SHIPPED BESIDE IT (hq_icon 2026-09-25, ceo CEO-1272 (b)).
#
# icont links ucode, never source. test_monitor_3way_sync_step_auto.sh compiled the icx participant with `icont -s` alone, so a
# program whose `link` names a library beside it -- every CEO-1269 NAME_driver, io_lib, lists_lib -- died in the icx compile with
# "cannot resolve reference to file 'NAME.u1'" and monitor_run.sh --oracle REFUSED: no bracket was possible on a linked program.
# The harness now finds every library the program reaches in SCRIP's own search order (icon_driver.c icn_link_open: IPATH,
# ICONPATH, the IPL procs beside the scrip binary, the linking file's directory), translates it into its scratch directory, and
# icont links from there, so both participants run the same library source.
#
# THE WITNESS: a scratch main that links a scratch library, which links a second one -- a two-deep closure, one statement per
# line so the bracket grades linking and nothing else -- must read AGREE under monitor_run.sh --oracle. On the harness before
# this change the same pair REFUSES (the icx compile), which is this gate's red.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_icn_monitor_icx_links_what_scrip_links
[ -x "$HERE/../../SCRIP/scrip" ] || { echo "⛔ GATE REFUSE(2) [$G]: scrip not built"; exit 2; }
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"; S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
IM="${ICON_MON_ROOT:-$S4A/icon-mon}"
[ -x "$IM/bin/icont" ] && [ -x "$IM/bin/iconx" ] || { echo "⛔ GATE REFUSE(2) [$G]: the instrumented Icon fork is not built at $IM -- this gate cannot measure without icx"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/icxlink_gate.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
cat > "$T/gate_icx_lib2.icn" <<'EOF'
procedure inc(x)
   return x + 1;
end
EOF
cat > "$T/gate_icx_lib1.icn" <<'EOF'
link gate_icx_lib2
procedure twice(x)
   local y;
   y := 2 * x;
   return inc(y) - 1;
end
EOF
cat > "$T/gate_icx_main.icn" <<'EOF'
link gate_icx_lib1
procedure main()
   local n;
   n := twice(21);
   write(n);
   write(twice(n));
end
EOF
out="$(cd "$T" && timeout -k 5 600 bash "$HERE/monitor_run.sh" gate_icx_main.icn --oracle 2>&1)"; rc=$?
line="$(printf '%s\n' "$out" | grep -E '^\[monitor_run\] (AGREE|DIVERGE)|REFUSE' | tail -1 | cut -c1-200)"
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^\[monitor_run\] AGREE'; then
    echo "  $line"
    echo "✅ GATE PASS [$G]: a program linking a two-deep library closure brackets AGREE against icx"; exit 0
fi
echo "  rc=$rc $line"
echo "⛔ GATE FAIL [$G]: the linked witness did not bracket AGREE -- the icx participant cannot link what SCRIP links"; exit 1
