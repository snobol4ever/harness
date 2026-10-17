#!/usr/bin/env bash
# test_gate_pristine_lock_timeout.sh -- NEGATIVE-TEST gate for row
# `build-governor-holds-pristine-while-box-idles`.
#
# Behavioral gate on ../harness/scripts/lib_pristine_lock.sh, the bounded-wait wrapper the Makefile's `pristine`/
# `pristine-all` targets now use around BUILD_LOCK instead of a bare unbounded `flock`. Proves: (1) an
# uncontended acquire runs the wrapped command and passes its exit code through verbatim; (2) a holder
# that releases BEFORE the bound lets the wrapped command proceed once free (the sibling row
# make-pristine-per-root-flock-second-builder-waits' own "second builder waits, then runs" contract,
# unweakened by this change); (3) THE ROW'S OWN POINT -- a holder that outlives the bound produces a
# REFUSAL (rc=99), never a silent hang, and the wrapped command NEVER RUNS (checked by absence of its
# side effect, not just the return code, same discipline test_gate_build_governor.sh uses for its
# analogous refusal assertions); (4) the refusal diagnostic actually names something (not a bare exit
# code with no explanation -- the whole complaint against the old mechanism was silence); (5)/(6) a bad
# lock path refuses (rc=98) and a missing command refuses (rc=64), the usage-error edges.
#
# Per lib_gate.sh's three-way contract: 0 CLEAN, 1 VIOLATION (an assertion below failed), 2 UNPROVEN
# (flock/fuser or the library itself is missing, so nothing could be examined).
#
# ⛔ ISOLATION IS LOAD-BEARING: every assertion runs against a SCRATCH lockfile, never the real
# per-root /tmp/si_pristine_lock-* -- a gate run must never contend with a genuine fleet pristine build.
# All timeouts here are test-scaled (1-2s), not the real 1200s default.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

FLOCK_BIN="$(command -v flock || true)"
gate_require_exec "${FLOCK_BIN:-/nonexistent}" "flock(1) binary"
FUSER_BIN="$(command -v fuser || true)"
gate_require_exec "${FUSER_BIN:-/nonexistent}" "fuser(1) binary"
gate_require "$HERE/lib_pristine_lock.sh" "lib_pristine_lock.sh"

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
LOCK="$SCRATCH/pristine.lock"
MARK="$SCRATCH/holder-acquired"
SIDE="$SCRATCH/wrapped-ran"

VIOL=0
TESTS_RUN=0
fail() { VIOL=$((VIOL + 1)); printf 'FAIL: %s\n' "$1" >&2; }
ok()   { printf '  ok: %s\n' "$1"; }

# wait_for_file <path> <max-tenths-of-a-second> -- generous poll for a background holder to signal it
# has the lock, mirroring test_gate_build_governor.sh's helper of the same name/shape.
wait_for_file() {
    local f="$1" n="$2" i=0
    while [ ! -e "$f" ]; do
        i=$((i + 1))
        [ "$i" -le "$n" ] || return 1
        sleep 0.1
    done
    return 0
}

# --- 1: uncontended acquire runs the wrapped command; its exit code passes through verbatim.
TESTS_RUN=$((TESTS_RUN + 1))
S4E_PRISTINE_LOCK_TIMEOUT=5 bash "$HERE/lib_pristine_lock.sh" "$LOCK" -- bash -c 'exit 17'; rc=$?
[ "$rc" -eq 17 ] && ok "uncontended acquire runs the command, exit code (17) passes through verbatim" \
                  || fail "expected the wrapped command's exit code (17) uncontended, got rc=$rc"

# --- 2: a holder that releases BEFORE the bound -- wrapped command proceeds once free (regression
#         safety net: this must not weaken make-pristine-per-root-flock-second-builder-waits' contract).
TESTS_RUN=$((TESTS_RUN + 1)); rm -f "$MARK" "$SIDE"
( flock "$LOCK" -c "touch '$MARK'; sleep 1" ) & HOLDPID=$!
if wait_for_file "$MARK" 50; then
    S4E_PRISTINE_LOCK_TIMEOUT=8 bash "$HERE/lib_pristine_lock.sh" "$LOCK" -- bash -c "touch '$SIDE'"; rc=$?
    [ "$rc" -eq 0 ] && [ -e "$SIDE" ] && ok "holder releases before the bound -> wrapped command proceeds once free" \
                     || fail "expected rc=0 and side effect present after the holder released, got rc=$rc side=$([ -e "$SIDE" ] && echo yes || echo no)"
else
    fail "test setup: background holder never signaled readiness"
fi
wait "$HOLDPID" 2>/dev/null

# --- 3: THE ROW'S OWN POINT -- a holder that OUTLIVES the bound -> REFUSAL (rc=99), and the wrapped
#         command NEVER RUNS (absence of side effect, not just the code -- point 4's actual claim).
TESTS_RUN=$((TESTS_RUN + 1)); rm -f "$MARK" "$SIDE"
( flock "$LOCK" -c "touch '$MARK'; sleep 6" ) & HOLDPID=$!
if wait_for_file "$MARK" 50; then
    S4E_PRISTINE_LOCK_TIMEOUT=1 bash "$HERE/lib_pristine_lock.sh" "$LOCK" -- bash -c "touch '$SIDE'" \
        >"$SCRATCH/t3.out" 2>"$SCRATCH/t3.err"
    rc=$?
    if [ "$rc" -eq 99 ] && [ ! -e "$SIDE" ]; then
        ok "holder outlives the bound -> refuses rc=99 and the wrapped command never runs"
    else
        sfx=no; [ -e "$SIDE" ] && sfx=yes
        fail "holder outliving the bound: expected rc=99 and no side effect, got rc=$rc, wrapped-command-ran=$sfx"
    fi
else
    fail "test setup: background long-lived holder never signaled readiness"
fi
wait "$HOLDPID" 2>/dev/null

# --- 4: the refusal is DIAGNOSED, not silent -- this row exists because the old mechanism said nothing
#         while it held for hours. The diagnostic must name the holder, not just announce a bare code.
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q 'PRISTINE-LOCK REFUSED' "$SCRATCH/t3.err" 2>/dev/null && grep -qE 'pid [0-9]+' "$SCRATCH/t3.err" 2>/dev/null; then
    ok "refusal diagnostic names the holder (not a silent/bare failure)"
else
    fail "refusal diagnostic missing or did not name a holder pid; stderr was: $(cat "$SCRATCH/t3.err" 2>/dev/null)"
fi

# --- 5: a bad lock path (parent directory missing) -> rc=98, wrapped command never runs.
TESTS_RUN=$((TESTS_RUN + 1)); rm -f "$SIDE"
bash "$HERE/lib_pristine_lock.sh" "$SCRATCH/nonexistent-dir-xyz/lock" -- bash -c "touch '$SIDE'" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 98 ] && [ ! -e "$SIDE" ]; then
    ok "unopenable lock path (missing parent dir) refuses rc=98 and never runs the wrapped command"
else
    sfx=no; [ -e "$SIDE" ] && sfx=yes
    fail "bad lock path: expected rc=98 and no side effect, got rc=$rc, wrapped-command-ran=$sfx"
fi

# --- 6: no command given -> usage error rc=64.
TESTS_RUN=$((TESTS_RUN + 1))
bash "$HERE/lib_pristine_lock.sh" "$LOCK" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 64 ] && ok "missing wrapped command refuses rc=64 (usage error)" \
                  || fail "expected rc=64 for a missing wrapped command, got rc=$rc"

gate_floor "$TESTS_RUN" 6 "pristine-lock-timeout negative-test assertions"
gate_verdict "$VIOL" "pristine-lock-timeout assertion(s) failed"
