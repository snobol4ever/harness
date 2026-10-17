#!/usr/bin/env bash
# build_rakudo_mon.sh <prefix> -- builds the INSTRUMENTED Rakudo fork (participant rkx) from the pristine 2026.05 release tarball
# under /home/resources plus rakudo-mon.patch, against the already-installed MoarVM/NQP of the shared oracle (rakudo-local); ends in
# the CONTROL ARM: with the pipes unset the fork's stdout and rc equal the pristine oracle's on the Raku witness. RAKUDO_MON_ROOT
# names the prefix for the harness; the default /home/resources/rakudo-mon is Lon's to install. Measured 2026-09-23 (cfo): about
# 12 minutes at load 10 on 16 cores, dominated by the three CORE settings the patched compiler must recompile.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../../../.." && pwd)}"
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
TARBALL="${RAKUDO_PRISTINE_TARBALL:-$S4A/rakudo-2026.05.tar.gz}"
NQP="${RAKUDO_WITH_NQP:-$S4A/rakudo-local/bin/nqp-m}"
PRI="${RAKUDO_PRISTINE_BIN:-$S4A/rakudo-local/bin/raku}"
DST="${1:-${RAKUDO_MON_ROOT:-$S4A/rakudo-mon}}"
WIT="$HERE/../../SCRIP/witnesses/sync_step_raku.raku"
[ -f "$TARBALL" ] || { echo "REFUSE(2): pristine Rakudo release tarball not found at $TARBALL (RAKUDO_PRISTINE_TARBALL names it)"; exit 2; }
[ -x "$NQP" ] || { echo "REFUSE(2): no installed nqp-m at $NQP (RAKUDO_WITH_NQP names it) -- the fork links against the shared oracle's MoarVM/NQP"; exit 2; }
[ -x "$PRI" ] || { echo "REFUSE(2): no pristine raku at $PRI (RAKUDO_PRISTINE_BIN names it) -- the control arm needs it"; exit 2; }
for t in tar patch make gcc perl; do command -v "$t" >/dev/null || { echo "REFUSE(2): $t missing"; exit 2; }; done
[ -f "$WIT" ] || { echo "REFUSE(2): witness missing at $WIT"; exit 2; }
mkdir -p "$DST" || { echo "REFUSE(2): cannot create $DST"; exit 2; }
rm -rf "$DST/build"; mkdir -p "$DST/build"
tar xzf "$TARBALL" -C "$DST/build" --strip-components=1 || { echo "REFUSE(2): unpacking $TARBALL into $DST/build failed"; exit 2; }
cp "$HERE/monitor_ipc_lib.c" "$HERE/monitor_ipc_lib.h" "$HERE/monitor_rkx.c" "$DST/build/src/vm/moar/ops/" || exit 2
( cd "$DST/build" && patch -p1 --forward --silent < "$HERE/rakudo-mon.patch" ) || { echo "REFUSE(2): rakudo-mon.patch did not apply cleanly on $TARBALL (re-cut it against the release)"; exit 2; }
LOG="$DST/build_rakudo_mon.log"
( cd "$DST/build" && perl Configure.pl --prefix="$DST" --backends=moar --with-nqp="$NQP" && make && make install ) > "$LOG" 2>&1 \
    || { echo "REFUSE(2): configure/make/install of the fork failed -- $(grep -m2 -iE '\berror\b' "$LOG" | head -2) ($LOG)"; exit 2; }
[ -x "$DST/bin/raku" ] || { echo "REFUSE(2): the build left no $DST/bin/raku"; exit 2; }
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
cp "$WIT" "$W/w.raku"
( cd "$W" && "$DST/bin/raku" --target=ast w.raku > f.ast 2>&1 )
hooks=$(grep -cE 'p6monstmt|p6moncall|p6monval|p6monret' "$W/f.ast" 2>/dev/null || true)
[ "${hooks:-0}" -ge 4 ] || { echo "FAIL(1): the fork's compiler emitted $hooks fire-points into the witness's AST (want statement, call, value and return) -- $(head -2 "$W/f.ast")"; exit 1; }
( cd "$W" && "$DST/bin/raku" w.raku < /dev/null > f.out 2> f.err; echo $? > f.rc )
( cd "$W" && "$PRI" w.raku < /dev/null > p.out 2> p.err; echo $? > p.rc )
if cmp -s "$W/f.out" "$W/p.out" && cmp -s "$W/f.rc" "$W/p.rc"; then
    echo "build_rakudo_mon: OK -- $DST/bin/raku built ($("$DST/bin/raku" --version | head -1), $hooks fire-points in the witness's AST); CONTROL: with the pipes unset the fork's output and rc equal the pristine oracle's ($PRI) on sync_step_raku.raku"
else
    echo "FAIL(1): the fork's untraced output or rc differs from the pristine oracle's (a fire-point is not silent) -- diff $W/f.out $W/p.out; rc $(cat "$W/f.rc") vs $(cat "$W/p.rc")"; diff "$W/f.out" "$W/p.out" | head -5; exit 1
fi
