#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../../../.." && pwd)}"
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
SRC="${SWIPL_PRISTINE:-$S4A/swipl-devel-master}"
DST="${1:-${SWIPL_MON_ROOT:-$S4A/swipl-mon}}"
PRI="${SWIPL_PRISTINE_BIN:-$DST/pristine/bin}"
WIT="$HERE/../../SCRIP/witnesses"
[ -d "$SRC/src" ] && [ -f "$SRC/boot/init.pl" ] || { echo "REFUSE(2): pristine SWI-Prolog drop not found at $SRC (SWIPL_PRISTINE names it)"; exit 2; }
for t in rsync patch make gcc cmake python3; do command -v "$t" >/dev/null || { echo "REFUSE(2): $t missing"; exit 2; }; done
ls "$WIT"/sync_step_prolog*.pl > /dev/null 2>&1 || { echo "REFUSE(2): no Prolog witnesses at $WIT"; exit 2; }
mkdir -p "$DST" || { echo "REFUSE(2): cannot create $DST"; exit 2; }
build_tree() {
    local kind="$1" prefix="$2" tree="$DST/$1-build" log="$DST/build_swipl_mon.$1.log"
    mkdir -p "$tree" && rsync -a --delete --exclude .git "$SRC/" "$tree/src/" || { echo "REFUSE(2): copy of the pristine drop into $tree/src failed"; return 2; }
    if [ "$kind" = fork ]; then
        cp "$HERE/monitor_ipc_lib.c" "$HERE/monitor_ipc_lib.h" "$HERE/monitor_swx.c" "$tree/src/src/" || return 2
        ( cd "$tree/src" && patch -p1 --forward --silent < "$HERE/swipl-mon.patch" ) || { echo "REFUSE(2): swipl-mon.patch did not apply cleanly on $SRC (re-cut it against the drop)"; return 2; }
    fi
    rm -rf "$tree/obj" && mkdir -p "$tree/obj" || return 2
    ( cd "$tree/obj" && cmake -DSWIPL_PACKAGES=OFF -DINSTALL_DOCUMENTATION=OFF -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX="$prefix" ../src && make -j"${SWIPL_MON_JOBS:-8}" && make install ) > "$log" 2>&1 \
        || { echo "REFUSE(2): cmake/make/install of the $kind tree failed -- $(grep -m2 -iE '\berror\b' "$log" | head -2) ($log)"; return 2; }
    [ -x "$prefix/bin/swipl" ] || { echo "REFUSE(2): the $kind build left no $prefix/bin/swipl"; return 2; }
    return 0
}
if [ ! -x "$PRI/swipl" ]; then
    build_tree pristine "$DST/pristine" || exit 2
    PRI="$DST/pristine/bin"
fi
build_tree fork "$DST" || exit 2
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
cp "$WIT/sync_step_prolog.pl" "$W/w.pl"
fired=$(timeout -k 5 120 python3 - "$DST/bin/swipl" "$W/w.pl" "$W" <<'PY'
import os, struct, subprocess, sys
swipl, wit, d = sys.argv[1:4]
r, g = os.path.join(d, 'ready'), os.path.join(d, 'go'); os.mkfifo(r); os.mkfifo(g)
p = subprocess.Popen([swipl, wit], env=dict(os.environ, MONITOR_READY_PIPE=r, MONITOR_GO_PIPE=g), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
rf = open(r, 'rb'); gf = open(g, 'wb', buffering=0); n = {}
while True:
    h = rf.read(13)
    if len(h) < 13: break
    kind, _, _, vlen = struct.unpack('<IIBI', h)
    if vlen: rf.read(vlen)
    n[kind] = n.get(kind, 0) + 1
    if kind == 4: break
    gf.write(b'G')
p.wait(timeout=60)
print(n.get(5, 0), n.get(2, 0), n.get(3, 0), n.get(4, 0))
PY
)
read -r nstmt ncall nret nend <<<"${fired:-0 0 0 0}"
[ "${nstmt:-0}" -gt 0 ] && [ "${ncall:-0}" -gt 0 ] && [ "${nret:-0}" -gt 0 ] && [ "${nend:-0}" = 1 ] \
    || { echo "FAIL(1): the fork's fire-points did not all fire on sync_step_prolog.pl over a live wire -- statement=$nstmt call=$ncall return=$nret end=$nend (want each > 0 and one end)"; exit 1; }
bad=""
for w in "$WIT"/sync_step_prolog*.pl; do
    b=$(basename "$w")
    ( cd "$W" && "$PRI/swipl" "$w" < /dev/null > p.out 2> /dev/null; echo $? > p.rc )
    ( cd "$W" && "$DST/bin/swipl" "$w" < /dev/null > f.out 2> /dev/null; echo $? > f.rc )
    ( cd "$W" && SWIPL_MON=1 "$DST/bin/swipl" "$w" < /dev/null > m.out 2> /dev/null; echo $? > m.rc )
    cmp -s "$W/p.out" "$W/f.out" && cmp -s "$W/p.rc" "$W/f.rc" && cmp -s "$W/p.out" "$W/m.out" && cmp -s "$W/p.rc" "$W/m.rc" || bad="$bad $b"
done
[ -z "$bad" ] || { echo "FAIL(1): the fork's untraced output or rc differs from the pristine build's ($PRI) on:$bad -- a fire-point or the clause injection is not silent"; exit 1; }
echo "build_swipl_mon: OK -- $DST/bin/swipl built (SWI-Prolog $(cat "$SRC/VERSION" 2>/dev/null)); on a live wire sync_step_prolog.pl fired $nstmt statement, $ncall call and $nret return record(s) and one end; CONTROL: with the pipes unset, and with the injection forced on by SWIPL_MON=1, the fork's stdout and rc equal the pristine build's ($PRI) on $(ls "$WIT"/sync_step_prolog*.pl | wc -l) witnesses"
