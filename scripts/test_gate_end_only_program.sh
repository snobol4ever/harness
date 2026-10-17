#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_end_only_program.sh -- floor-case regression gate for row end-only-program-aborts.
#
# THE INVARIANT: the smallest legal SNOBOL4 program -- a bare `END` statement, 4 bytes,
# no other statements -- must exit 0 with zero bytes of output in BOTH modes.  Before
# SCRIP `f7c25eb6`, a zero-statement program left main_bb_idx unset, tripping the
# driver's "main BB graph not found" guard: abort()/SIG6 in mode-3
# (src/driver/scrip.c:1671) and a clean COMPILE_FAIL in mode-4 (scrip.c:1389). The
# oracle (x64/bin/sbl -bf) agrees the program is legal and silent: rc 0, 0 bytes.
#
# NOT covered here (deliberately): a genuinely 0-byte source file. MEASURED to diverge
# from the oracle -- `x64/bin/sbl -bf` on an empty file answers rc=1 "No END statement
# found in source file(s)", while SCRIP currently answers rc=0 like bare END. Asserting
# 0-byte-succeeds here would gate in that divergence as if it were correct. See the
# FINDING for row end-only-program-aborts (flagged, not fixed, separate row proposed).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: sibling root; S4E_HOME overrides
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP_BIN="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
CORPUS_ROOT="${CORPUS:-$S4E/corpus}"

[ -x "$SCRIP_BIN" ] || { echo "GATE FAIL(2): scrip not built at $SCRIP_BIN"; exit 2; }

WORKDIR=$(mktemp -d); trap 'rm -rf "$WORKDIR"' EXIT
FAIL=0

check_m3() {  # name path
    local name="$1" src="$2" out rc
    out=$(timeout -k 5 8 "$SCRIP_BIN" "$src" < /dev/null 2>"$WORKDIR/m3.err"); rc=$?
    if [ "$rc" -ne 0 ] || [ -n "$out" ]; then
        echo "FAIL m3 $name: rc=$rc bytes=${#out} (want rc=0, 0 bytes)"
        [ -s "$WORKDIR/m3.err" ] && sed 's/^/    /' "$WORKDIR/m3.err"
        FAIL=1
    else
        echo "OK   m3 $name: rc=0, 0 bytes"
    fi
}

check_m4() {  # name path
    local name="$1" src="$2" out rc
    timeout -k 5 8 "$SCRIP_BIN" --compile "$src" > "$WORKDIR/p.s" 2>"$WORKDIR/emit.err" < /dev/null
    if [ ! -s "$WORKDIR/p.s" ]; then
        echo "FAIL m4 $name: compile emitted nothing"; sed 's/^/    /' "$WORKDIR/emit.err"; FAIL=1; return
    fi
    if ! gcc -c "$WORKDIR/p.s" -o "$WORKDIR/p.o" 2>"$WORKDIR/as.err"; then
        echo "FAIL m4 $name: assemble failed"; sed 's/^/    /' "$WORKDIR/as.err"; FAIL=1; return
    fi
    if ! gcc -no-pie "$WORKDIR/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$WORKDIR/p.bin" 2>"$WORKDIR/link.err"; then
        echo "FAIL m4 $name: link failed"; sed 's/^/    /' "$WORKDIR/link.err"; FAIL=1; return
    fi
    out=$(timeout -k 5 8 "$WORKDIR/p.bin" < /dev/null 2>"$WORKDIR/run.err"); rc=$?
    if [ "$rc" -ne 0 ] || [ -n "$out" ]; then
        echo "FAIL m4 $name: rc=$rc bytes=${#out} (want rc=0, 0 bytes)"
        [ -s "$WORKDIR/run.err" ] && sed 's/^/    /' "$WORKDIR/run.err"
        FAIL=1
    else
        echo "OK   m4 $name: rc=0, 0 bytes"
    fi
}

echo "=== end-only-program floor gate ==="
printf 'END\n' > "$WORKDIR/end_only.sno"
check_m3 "bare-END" "$WORKDIR/end_only.sno"
check_m4 "bare-END" "$WORKDIR/end_only.sno"

SUITE="$CORPUS_ROOT/packages/snobol4/csnobol4_suite"
for w in preload1 preload2 preload3 preload4 end; do
    f="$SUITE/$w.sno"
    if [ ! -f "$f" ]; then
        echo "SKIP  $w: witness not found at $f"
        continue
    fi
    check_m3 "$w" "$f"
    check_m4 "$w" "$f"
done

if [ "$FAIL" -ne 0 ]; then
    echo "GATE FAIL: end-only-program floor regressed."
    exit 1
fi
echo "GATE OK: bare-END and the csnobol4_suite END-only witnesses exit 0 with zero output in both modes."
exit 0
