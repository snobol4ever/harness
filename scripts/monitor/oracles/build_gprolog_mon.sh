#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../../../.." && pwd)}"
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
SRC="${GPROLOG_PRISTINE:-$S4A/gprolog-master}"
DST="${1:-${GPROLOG_MON_ROOT:-$S4A/gprolog-mon}}"
PRI="${GPROLOG_PRISTINE_BIN:-$DST/pristine/bin}"
WIT="$HERE/../../SCRIP/witnesses/sync_step_prolog.pl"
[ -d "$SRC/src/EnginePl" ] && [ -d "$SRC/src/Pl2Wam" ] || { echo "REFUSE(2): pristine GNU Prolog drop not found at $SRC (GPROLOG_PRISTINE names it)"; exit 2; }
for t in rsync patch make gcc; do command -v "$t" >/dev/null || { echo "REFUSE(2): $t missing"; exit 2; }; done
[ -f "$WIT" ] || { echo "REFUSE(2): witness missing at $WIT"; exit 2; }
mkdir -p "$DST" || { echo "REFUSE(2): cannot create $DST"; exit 2; }
build_tree() {
    local tree="$1" prefix="$2" kind="$3" log="$DST/build_gprolog_mon.$3.log"
    rsync -a --delete --exclude .git "$SRC/" "$tree/" || { echo "REFUSE(2): copy of the pristine drop into $tree failed"; return 2; }
    if [ "$kind" = fork ]; then
        cp "$HERE/monitor_ipc_lib.c" "$HERE/monitor_ipc_lib.h" "$HERE/monitor_gpx.c" "$tree/src/EnginePl/" || return 2
        ( cd "$tree" && patch -p1 --forward --silent < "$HERE/gprolog-mon.patch" ) || { echo "REFUSE(2): gprolog-mon.patch did not apply cleanly on $SRC (re-cut it against the drop)"; return 2; }
        touch "$tree"/src/Pl2Wam/*.wam
    fi
    ( cd "$tree/src" && ./configure --prefix="$prefix" && make ) > "$log" 2>&1 || { echo "REFUSE(2): configure/make of the $kind tree failed -- $(grep -m2 -iE '\berror\b' "$log" | head -2) ($log)"; return 2; }
    if [ "$kind" = fork ]; then
        ( cd "$tree/src/Pl2Wam" && export PATH="$tree/src/TopComp:$tree/src/Pl2Wam:$tree/src/Wam2Ma:$tree/src/Ma2Asm:$PATH" && ./pl2wam --fast-math pl2wam.pl && ./pl2wam --fast-math read_file.pl && sh fix-wam.sh pl2wam.wam read_file.wam && make ) >> "$log" 2>&1 \
            || { echo "REFUSE(2): recompiling the instrumented pl2wam.pl with the stage-1 pl2wam failed ($log)"; return 2; }
    fi
    ( cd "$tree/src" && make install-system install-links ) >> "$log" 2>&1 || { echo "REFUSE(2): make install-system install-links into $prefix failed ($log)"; return 2; }
    [ -x "$prefix/bin/gplc" ] || { echo "REFUSE(2): the $kind build left no $prefix/bin/gplc"; return 2; }
    return 0
}
if [ ! -x "$PRI/gplc" ]; then
    build_tree "$DST/pristine-build" "$DST/pristine" pristine || exit 2
    PRI="$DST/pristine/bin"
fi
build_tree "$DST/build" "$DST" fork || exit 2
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
cp "$WIT" "$W/w.pl"
( cd "$W" && PATH="$DST/bin:$PATH" "$DST/bin/gplc" -W -o f.wam w.pl ) > "$W/f.wam.out" 2>&1
hooks=$(grep -c "Pl_Mon_Stmt\|Pl_Mon_Call\|Pl_Mon_Return" "$W/f.wam" 2>/dev/null || true)
[ "${hooks:-0}" -ge 3 ] || { echo "FAIL(1): the fork's pl2wam emitted $hooks fire-points into the witness's WAM code (want statement, call and return) -- $(head -2 "$W/f.wam.out")"; exit 1; }
( cd "$W" && PATH="$DST/bin:$PATH" "$DST/bin/gplc" --no-top-level -o f.bin w.pl > f.cc 2>&1 && ./f.bin < /dev/null > f.out 2> f.err; echo $? > f.rc )
( cd "$W" && PATH="$PRI:$PATH" "$PRI/gplc" --no-top-level -o p.bin w.pl > p.cc 2>&1 && ./p.bin < /dev/null > p.out 2> p.err; echo $? > p.rc )
if cmp -s "$W/f.out" "$W/p.out" && cmp -s "$W/f.rc" "$W/p.rc"; then
    echo "build_gprolog_mon: OK -- $DST/bin/gplc built (GNU Prolog $(cat "$SRC/VERSION" 2>/dev/null | sed 's/gprolog-//'), $hooks fire-points in the witness's WAM); CONTROL: with the pipes unset the fork's output and rc equal the pristine build's ($PRI) on sync_step_prolog.pl"
else
    echo "FAIL(1): the fork's untraced output or rc differs from the pristine build's (a fire-point is not silent) -- diff $W/f.out $W/p.out; rc $(cat "$W/f.rc") vs $(cat "$W/p.rc")"; diff "$W/f.out" "$W/p.out" | head -5; exit 1
fi
