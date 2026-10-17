#!/usr/bin/env bash
# build_fpc_mon.sh <prefix> -- build the SCRIP fork of Free Pascal that is INSTRUMENTED IN ITS OWN SOURCE with the IPC sync-step
# monitor's comm calls (coo 2026-09-23, on Lon's word to the coo at 06:32 CDT: "Build the Free Pascal Compiler (FPC) IPC sync-step
# monitor inside FPC just like CEO did for Icon and Prolog"; the standard is MONITOR-BINARY-DESIGN.md section THE ORACLES ARE
# INSTRUMENTED IN THEIR OWN SOURCE, CEO-1189; the precedents SCRIP d85e6186d (Icon) and 4a9d5a698 (GNU Prolog)).
#
# From the pristine /home/resources/FPCSource drop (main, 3.3.1; the recorded oracle /usr/bin/fpc is 3.2.2, which is also the
# starting compiler) plus fpc-mon.patch and three new files (monitor_fpx_nmonipc.pas -> compiler/nmonipc.pas, the injector;
# monitor_fpx_monipc.inc / monitor_fpx_monipch.inc -> rtl/inc/, the fire-points speaking the wire in Pascal with the system
# unit's own syscalls, since an FPC program links no libc). The fork's compiler takes -gi: every element of every statement
# list fires the statement event with its source line, every store to a named variable and every for-loop iteration fires the
# value event, every user procedure fires call at entry and return at its exit label. Without -gi the fork compiles exactly as
# the drop does; with -gi and the pipes unset the fire-points are silent no-ops -- the CONTROL ARM at the end proves the fork's
# stdout and rc equal the pristine 3.3.1 build's on the witness. The participant lives BESIDE the oracle, never in its place.
#
#   <prefix>/bin/fpc          the fork's driver: ppcx64 -n -Fu<prefix>/lib/units "$@"   (use: fpc -Miso -gi -o prog prog.pas)
#   <prefix>/lib/ppcx64       the forked compiler        <prefix>/lib/units   its RTL       <prefix>/pristine/bin/fpc  the control
#   FPC_MON_ROOT names the prefix for the harness (default /home/resources/fpc-mon, which only Lon or a seat that may write
#   under /home/resources installs); FPC_PRISTINE names the drop, FPC_START the starting compiler, FPC_PRISTINE_BIN a control
#   build to reuse. Measured 2026-09-23: about 45 s for the fork and 30 s for the pristine build at load 3.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../../../.." && pwd)}"
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
SRC="${FPC_PRISTINE:-$S4A/FPCSource}"
DST="${1:-${FPC_MON_ROOT:-$S4A/fpc-mon}}"
PRI="${FPC_PRISTINE_BIN:-$DST/pristine/bin}"
START="${FPC_START:-/usr/bin/fpc}"
WIT="$HERE/../../SCRIP/witnesses/sync_step_pascal.pas"
[ -f "$SRC/compiler/pp.pas" ] && [ -f "$SRC/rtl/inc/system.inc" ] || { echo "REFUSE(2): pristine Free Pascal drop not found at $SRC (FPC_PRISTINE names it)"; exit 2; }
[ -x "$START" ] || { echo "REFUSE(2): no starting compiler at $START (FPC_START names it; the recorded oracle /usr/bin/fpc 3.2.2 is the default)"; exit 2; }
for t in rsync patch make objdump; do command -v "$t" >/dev/null || { echo "REFUSE(2): $t missing"; exit 2; }; done
[ -f "$WIT" ] || { echo "REFUSE(2): witness missing at $WIT"; exit 2; }
for f in fpc-mon.patch monitor_fpx_nmonipc.pas monitor_fpx_monipc.inc monitor_fpx_monipch.inc; do [ -f "$HERE/$f" ] || { echo "REFUSE(2): $HERE/$f missing"; exit 2; }; done
mkdir -p "$DST" || { echo "REFUSE(2): cannot create $DST"; exit 2; }
build_tree() {
    local tree="$1" prefix="$2" kind="$3" log="$DST/build_fpc_mon.$3.log"
    rsync -a --delete --exclude .git "$SRC/" "$tree/" || { echo "REFUSE(2): copy of the pristine drop into $tree failed"; return 2; }
    if [ "$kind" = fork ]; then
        cp "$HERE/monitor_fpx_nmonipc.pas" "$tree/compiler/nmonipc.pas" || return 2
        cp "$HERE/monitor_fpx_monipc.inc" "$tree/rtl/inc/monipc.inc" || return 2
        cp "$HERE/monitor_fpx_monipch.inc" "$tree/rtl/inc/monipch.inc" || return 2
        ( cd "$tree" && patch -p1 --forward --silent < "$HERE/fpc-mon.patch" ) || { echo "REFUSE(2): fpc-mon.patch did not apply cleanly on $SRC (re-cut it against the drop)"; return 2; }
    fi
    ( cd "$tree/compiler" && make FPC="$START" OPT="-O1" ) > "$log" 2>&1 || { echo "REFUSE(2): make of the $kind compiler failed -- $(grep -m2 -E 'Error:|Fatal:' "$log" | head -2) ($log)"; return 2; }
    [ -x "$tree/compiler/ppcx64" ] || { echo "REFUSE(2): the $kind compiler build left no $tree/compiler/ppcx64 ($log)"; return 2; }
    ( cd "$tree/rtl" && make clean && make FPC="$tree/compiler/ppcx64" ) >> "$log" 2>&1 || { echo "REFUSE(2): make of the $kind RTL with its own compiler failed -- $(grep -m2 -E 'Error:|Fatal:' "$log" | head -2) ($log)"; return 2; }
    [ -f "$tree/rtl/units/x86_64-linux/system.ppu" ] || { echo "REFUSE(2): the $kind RTL build left no system.ppu ($log)"; return 2; }
    rm -rf "$prefix/lib" "$prefix/bin/fpc" && mkdir -p "$prefix/bin" "$prefix/lib/units" || return 2
    cp "$tree/compiler/ppcx64" "$prefix/lib/ppcx64" && cp -r "$tree/rtl/units/x86_64-linux/." "$prefix/lib/units/" || { echo "REFUSE(2): install into $prefix failed"; return 2; }
    cat > "$prefix/bin/fpc" <<'WRAP'
#!/usr/bin/env bash
# fpc-mon: the SCRIP fork of Free Pascal (build_fpc_mon.sh). -n ignores every fpc.cfg so the fork's own RTL is the one linked;
# -gi injects the IPC sync-step monitor's fire-points (see ../harness/scripts/monitor/oracles/monitor_fpx_monipch.inc for the contract).
R="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
exec "$R/lib/ppcx64" -n -Fu"$R/lib/units" "$@"
WRAP
    chmod +x "$prefix/bin/fpc"
    [ -x "$prefix/bin/fpc" ] || { echo "REFUSE(2): the $kind install left no $prefix/bin/fpc"; return 2; }
    return 0
}
if [ ! -x "$PRI/fpc" ]; then
    build_tree "$DST/pristine-build" "$DST/pristine" pristine || exit 2
    PRI="$DST/pristine/bin"
fi
build_tree "$DST/build" "$DST" fork || exit 2
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
cp "$WIT" "$W/w.pas"
( cd "$W" && "$DST/bin/fpc" -Miso -gi -v0 -FE"$W" -o"$W/f.bin" w.pas ) > "$W/f.cc" 2>&1 || { echo "FAIL(1): the fork's compiler refused the witness under -gi -- $(tail -2 "$W/f.cc")"; exit 1; }
stmt=$(objdump -d --no-show-raw-insn "$W/f.bin" | grep -ci 'call.*fpc_mon_stmt' || true)
ev=$(objdump -d --no-show-raw-insn "$W/f.bin" | grep -ci 'call.*fpc_mon_ev_' || true)
[ "${stmt:-0}" -ge 1 ] && [ "${ev:-0}" -ge 1 ] || { echo "FAIL(1): the fork emitted $stmt statement and $ev value fire-points into the witness (want at least one of each)"; exit 1; }
( cd "$W" && ./f.bin < /dev/null > f.out 2> f.err; echo $? > f.rc )
( cd "$W" && "$PRI/fpc" -Miso -v0 -FE"$W" -o"$W/p.bin" w.pas > p.cc 2>&1 && ./p.bin < /dev/null > p.out 2> p.err; echo $? > p.rc )
ver=$("$DST/lib/ppcx64" -iV 2>/dev/null)
if cmp -s "$W/f.out" "$W/p.out" && cmp -s "$W/f.rc" "$W/p.rc"; then
    echo "build_fpc_mon: OK -- $DST/bin/fpc built (Free Pascal $ver from $SRC, started from $START $("$START" -iV 2>/dev/null); $stmt statement and $ev value fire-points in the witness); CONTROL: with the pipes unset the fork's output and rc equal the pristine $ver build's ($PRI) on sync_step_pascal.pas"
else
    echo "FAIL(1): the fork's untraced output or rc differs from the pristine build's (a fire-point is not silent) -- diff $W/f.out $W/p.out; rc $(cat "$W/f.rc") vs $(cat "$W/p.rc")"; diff "$W/f.out" "$W/p.out" | head -5; exit 1
fi
