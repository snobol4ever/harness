#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../../../.." && pwd)}"
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
SRC="${ICON_PRISTINE:-$S4A/icon-master}"
DST="${1:-${ICON_MON_ROOT:-$S4A/icon-mon}}"
[ -d "$SRC/src/runtime" ] || { echo "REFUSE(2): pristine Icon drop not found at $SRC (ICON_PRISTINE names it)"; exit 2; }
[ -x "$SRC/bin/icont" ] && [ -x "$SRC/bin/iconx" ] || { echo "REFUSE(2): the pristine drop at $SRC is not built (bin/icont, bin/iconx) -- the control arm needs it"; exit 2; }
command -v rsync >/dev/null || { echo "REFUSE(2): rsync missing"; exit 2; }
mkdir -p "$DST" || { echo "REFUSE(2): cannot create $DST"; exit 2; }
rsync -a --delete --exclude .git "$SRC/" "$DST/" || { echo "REFUSE(2): copy of the pristine drop into $DST failed"; exit 2; }
cp "$HERE/monitor_ipc_lib.c" "$HERE/monitor_ipc_lib.h" "$HERE/monitor_icx.c" "$DST/src/runtime/" || exit 2
( cd "$DST" && patch -p1 --forward --silent < "$HERE/icon-mon.patch" ) || { echo "REFUSE(2): icon-mon.patch did not apply cleanly on $SRC (re-cut it against the drop)"; exit 2; }
( cd "$DST" && make Icont > "$DST/build_icon_mon.log" 2>&1 ) || { echo "REFUSE(2): make Icont failed -- $(grep -m2 -iE 'error' "$DST/build_icon_mon.log" | head -2)"; exit 2; }
[ -x "$DST/bin/icont" ] && [ -x "$DST/bin/iconx" ] || { echo "REFUSE(2): build left no bin/icont or bin/iconx under $DST"; exit 2; }
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
cp "$HERE/../../SCRIP/witnesses/sync_step_icon.icn" "$W/w.icn"
( cd "$W" && "$DST/bin/icont" -s -o f.bin w.icn && "$DST/bin/iconx" f.bin > f.out 2> f.err; echo $? > f.rc; "$SRC/bin/icont" -s -o p.bin w.icn && "$SRC/bin/iconx" p.bin > p.out 2> p.err; echo $? > p.rc )
if cmp -s "$W/f.out" "$W/p.out" && cmp -s "$W/f.rc" "$W/p.rc"; then
    echo "build_icon_mon: OK -- $DST/bin/{icont,iconx} built; CONTROL: with the pipes unset the fork's output and rc equal the pristine oracle's on sync_step_icon.icn"
else
    echo "FAIL(1): the fork's untraced output differs from the pristine oracle's (a fire-point is not silent) -- diff $W/f.out $W/p.out"; diff "$W/f.out" "$W/p.out" | head -5; exit 1
fi
