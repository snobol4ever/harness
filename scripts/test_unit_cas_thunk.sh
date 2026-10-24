#!/usr/bin/env bash
# test_unit_cas_thunk.sh -- unit gate for the C.A.S. EXPRESSION-THUNK entry kind
# (row lang-lambda-pattern-primitives; Lon: "++ at cursor-pass, -- on backtrack, pump at success").
#
# ⭐ WHY A UNIT GATE AND NOT A .sno WITNESS: the lambda SURFACE is on hold while Lon redesigns it, so a
# language-level witness would pin syntax that may still move. This drives the machinery through the
# runtime's exported entry points, so it keeps proving the same three properties whatever the surface
# becomes -- and it is the arm that a future surface change must not break.
# ⛔ REFUSES with rc=2 when it cannot measure (no RT built) rather than reporting a green skip.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
RT="${RT_DIR:-$ROOT/out}"
[ -f "$RT/libscrip_rt.so" ] || { echo "REFUSING rc=2: $RT/libscrip_rt.so missing -- cannot measure the C.A.S. thunk arm. Build first; a skip here would read as a pass." >&2; exit 2; }
BIN="$(mktemp -d)/cas_thunk_test"
trap 'rm -rf "${BIN%/*}"' EXIT INT TERM
gcc -O0 -g -Wall -o "$BIN" "$ROOT/tools/cas_thunk_test.c" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" 2>&1 || { echo "REFUSING rc=2: cas_thunk_test.c did not build against the RT" >&2; exit 2; }
"$BIN"; rc=$?
[ $rc -eq 0 ] && echo "✅ CAS-THUNK GATE OK" || echo "⛔ CAS-THUNK GATE FAIL (rc=$rc)"
exit $rc
