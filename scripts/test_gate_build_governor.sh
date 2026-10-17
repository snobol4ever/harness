#!/usr/bin/env bash
# test_gate_build_governor.sh -- NEGATIVE-TEST gate for row `build-governor-concurrent-pristine`.
#
# This is not a source-scan gate (there is no floor of "files examined") -- it is a behavioral gate on
# lib_build_governor.sh: prove the shared/exclusive exclusion actually excludes, and prove a corrupt/missing/
# unwritable semaphore path is a REFUSAL (rc=2) rather than a silent unguarded pass. Per lib_gate.sh's three-
# way contract: 0 CLEAN, 1 VIOLATION (an assertion below failed), 2 UNPROVEN (flock or the library itself is
# missing, so nothing could be examined).
#
# ⛔ ISOLATION IS LOAD-BEARING: every assertion below runs against a SCRATCH semaphore
# (S4E_GOVERNOR_LOCK, exported before the library is sourced), never the real shared
# /home/resources/postoffice/governor.lock. Up to 16 seats may run this gate at once; a gate run must never
# hold or contend for the real fleet semaphore.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

FLOCK_BIN="$(command -v flock || true)"
gate_require_exec "${FLOCK_BIN:-/nonexistent}" "flock(1) binary"
gate_require "$HERE/lib_build_governor.sh" "lib_build_governor.sh"

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
export S4E_GOVERNOR_LOCK="$SCRATCH/governor.lock"
. "$HERE/lib_build_governor.sh"

VIOL=0
TESTS_RUN=0
fail() { VIOL=$((VIOL + 1)); printf 'FAIL: %s\n' "$1" >&2; }
ok()   { printf '  ok: %s\n' "$1"; }

# wait_for_file <path> <max-tenths-of-a-second> -- generous poll for a background holder to signal it has
# the lock and is running. No wall-clock margin assumption anywhere in this gate (this box's run-to-run
# noise is the whole reason the row exists) -- only "did the marker appear before a generous deadline."
wait_for_file() {
    local f="$1" n="$2" i=0
    while [ ! -e "$f" ]; do
        i=$((i + 1))
        [ "$i" -le "$n" ] || return 1
        sleep 0.1
    done
    return 0
}

MARK="$SCRATCH/mark"

# --- 1: builds SHARE -- a second --try build succeeds while the first is still in flight.
TESTS_RUN=$((TESTS_RUN + 1)); rm -f "$MARK"
( governor_build -- bash -c "touch '$MARK'; sleep 1" ) & BG=$!
if wait_for_file "$MARK" 50; then
    governor_build --try -- true; rc=$?
    [ "$rc" -eq 0 ] && ok "builds share (concurrent --try build rc=0 while one in flight)" \
                     || fail "builds should share: expected rc=0 for a concurrent --try build, got rc=$rc"
else
    fail "test setup: background build never signaled readiness"
fi
wait "$BG" 2>/dev/null

# --- 2: a live BUILD blocks a --try BENCHMARK (exclusive must wait for shared holders too).
TESTS_RUN=$((TESTS_RUN + 1)); rm -f "$MARK"
( governor_build -- bash -c "touch '$MARK'; sleep 1" ) & BG=$!
if wait_for_file "$MARK" 50; then
    governor_bench --try -- true; rc=$?
    [ "$rc" -eq 3 ] && ok "live build blocks --try benchmark (rc=3 BUSY)" \
                     || fail "a live build should refuse a --try benchmark with rc=3 BUSY, got rc=$rc"
else
    fail "test setup: background build never signaled readiness"
fi
wait "$BG" 2>/dev/null

# --- 3: a live BENCHMARK blocks a --try BUILD (exclusive excludes shared).
TESTS_RUN=$((TESTS_RUN + 1)); rm -f "$MARK"
( governor_bench -- bash -c "touch '$MARK'; sleep 1" ) & BG=$!
if wait_for_file "$MARK" 50; then
    governor_build --try -- true; rc=$?
    [ "$rc" -eq 3 ] && ok "live benchmark blocks --try build (rc=3 BUSY)" \
                     || fail "a live benchmark should refuse a --try build with rc=3 BUSY, got rc=$rc"
else
    fail "test setup: background benchmark never signaled readiness"
fi
wait "$BG" 2>/dev/null

# --- 4: a live BENCHMARK blocks a second --try BENCHMARK (exclusive excludes exclusive) -- the row's own
#         literal ask: "hold the exclusive slot in one shell, assert a second exclusive taker is refused".
TESTS_RUN=$((TESTS_RUN + 1)); rm -f "$MARK"
( governor_bench -- bash -c "touch '$MARK'; sleep 1" ) & BG=$!
if wait_for_file "$MARK" 50; then
    governor_bench --try -- true; rc=$?
    [ "$rc" -eq 3 ] && ok "live benchmark blocks a second --try benchmark (rc=3 BUSY)" \
                     || fail "a live benchmark should refuse a second --try benchmark with rc=3 BUSY, got rc=$rc"
else
    fail "test setup: background benchmark never signaled readiness"
fi
wait "$BG" 2>/dev/null

# --- 5: the slot is free again once its holder exits cleanly -- no permanent stall.
TESTS_RUN=$((TESTS_RUN + 1))
governor_bench -- true
governor_bench --try -- true; rc=$?
[ "$rc" -eq 0 ] && ok "slot is free again after a clean exit" \
                 || fail "expected the slot free after its holder exited cleanly, got rc=$rc"

# --- 6: the WRAPPED COMMAND's own exit code passes through verbatim (never swallowed into 2/3).
TESTS_RUN=$((TESTS_RUN + 1))
governor_build -- bash -c 'exit 17'; rc=$?
[ "$rc" -eq 17 ] && ok "wrapped command's own exit code (17) passes through verbatim" \
                  || fail "expected the wrapped command's exit code (17) to pass through, got rc=$rc"

# --- 7: corrupt semaphore path (a directory where a file belongs) -> rc=2, AND the wrapped command NEVER
#         RUNS -- checked by absence of its side effect, not just by the return code (point 4's actual claim).
TESTS_RUN=$((TESTS_RUN + 1))
mkdir -p "$SCRATCH/corrupt-dir"; rm -f "$SCRATCH/should-not-exist"
( S4E_GOVERNOR_LOCK="$SCRATCH/corrupt-dir" bash -c ". '$HERE/lib_build_governor.sh'; governor_build -- touch '$SCRATCH/should-not-exist'" )
rc=$?
if [ "$rc" -eq 2 ] && [ ! -e "$SCRATCH/should-not-exist" ]; then
    ok "corrupt semaphore path (a directory) refuses rc=2 and never runs the wrapped command"
else
    sfx=no; [ -e "$SCRATCH/should-not-exist" ] && sfx=yes
    fail "corrupt semaphore path: expected rc=2 and no side effect, got rc=$rc, wrapped-command-ran=$sfx"
fi

# --- 8: missing semaphore parent directory -> rc=2.
TESTS_RUN=$((TESTS_RUN + 1))
( S4E_GOVERNOR_LOCK="$SCRATCH/nonexistent-dir-xyz/governor.lock" bash -c ". '$HERE/lib_build_governor.sh'; governor_build -- true" )
rc=$?
[ "$rc" -eq 2 ] && ok "missing semaphore directory refuses rc=2" \
                 || fail "missing semaphore directory: expected rc=2, got rc=$rc"

# --- 9: unwritable existing semaphore file -> rc=2 (root bypasses file permission bits, so skip there).
TESTS_RUN=$((TESTS_RUN + 1))
if [ "$(id -u)" = "0" ]; then
    ok "unwritable-semaphore-file check SKIPPED (running as root -- permission bits are not meaningful)"
else
    : > "$SCRATCH/readonly.lock"; chmod 400 "$SCRATCH/readonly.lock"
    ( S4E_GOVERNOR_LOCK="$SCRATCH/readonly.lock" bash -c ". '$HERE/lib_build_governor.sh'; governor_build -- true" )
    rc=$?
    chmod 600 "$SCRATCH/readonly.lock"
    [ "$rc" -eq 2 ] && ok "unwritable existing semaphore file refuses rc=2" \
                     || fail "unwritable semaphore file: expected rc=2, got rc=$rc"
fi

gate_floor "$TESTS_RUN" 9 "build-governor negative-test assertions"
gate_verdict "$VIOL" "build-governor assertion(s) failed"
