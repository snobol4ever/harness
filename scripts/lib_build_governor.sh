#!/usr/bin/env bash
# lib_build_governor.sh -- row `build-governor-concurrent-pristine`. Serializes the fleet's HEAVY windows
# (make pristine, full-corpus boards, benchmark runs) so a benchmark is never measuring while another root
# is mid-build. Sourceable (defines governor_build / governor_bench) AND directly executable (see dispatch
# at the bottom), so a Makefile recipe can invoke it without sourcing and a bash script can source it.
#
# ⭐ WHY THIS IS A READ/WRITE LOCK, NOT AN N-SLOT COUNTER. The row's own point 2 overrides its point 1's "N
# slots" phrasing: "N concurrent builds is merely slow; one build concurrent with one benchmark makes the
# benchmark a lie. Model it as a read/write lock -- builds share, a benchmark takes it exclusively." That IS
# flock's native shared (-s) vs exclusive (-x) mode on one file: unlimited concurrent -s holders, and -x
# waits for every -s (and any other -x) to release first. No hand-rolled counter needed or wanted -- a
# counter you maintain yourself is exactly the "lockdir of your own invention" the row forbids, because it
# does not release on process death the way flock's kernel-held lock does.
#
# ⛔ WHY THERE IS NO STALE-LOCK CLEANUP CODE. The row's DONE-WHEN prose says "missing, stale, unwritable" --
# but flock is held on an open file descriptor, released by the kernel the instant every fd referencing it
# closes, including on SIGKILL or a crash. There is no PID file to go stale and nothing here to sweep. Only
# the semaphore PATH can be unusable (missing parent dir, wrong file type, permissions) -- that is what
# _governor_preflight checks, and it is the only "stale" this design can even have.
#
# EXIT CODE CONTRACT (point 4: degrade to a refusal, never a silent pass):
#   2   governor infra failure -- preflight refused, or the lock itself could not be opened/acquired.
#       The wrapped command NEVER RUNS.
#   3   --try mode ONLY: the slot is held by a conflicting holder right now. The wrapped command NEVER RUNS.
#   64  usage error (no command given to wrap).
#   *   any other code is the WRAPPED COMMAND's own exit status, passed through verbatim.
# A caller can therefore always tell "governor refused" (2/3) from "the work itself failed" (anything else).
#
# USAGE (sourced):   . ../harness/scripts/lib_build_governor.sh
#                     governor_build [--try] -- <command...>   # SHARED slot -- builds run concurrently
#                     governor_bench [--try] -- <command...>   # EXCLUSIVE slot -- excludes builds AND other benchmarks
# USAGE (direct):     bash ../harness/scripts/lib_build_governor.sh build [--try] -- <command...>
#                     bash ../harness/scripts/lib_build_governor.sh bench [--try] -- <command...>
#
# S4E_GOVERNOR_LOCK overrides the semaphore path -- used by test_gate_build_governor.sh to run its negative
# tests against a scratch file instead of the real shared semaphore (a gate run must never contend with a
# genuine fleet build/benchmark).
GOV_LOCK="${S4E_GOVERNOR_LOCK:-/home/resources/postoffice/governor.lock}"

# _governor_preflight -- refuse loudly (rc=2) before ever touching flock, so a corrupt/missing/unwritable
# semaphore path is a REFUSAL, not an attempt that fails halfway through running the wrapped command.
_governor_preflight() {
    command -v flock >/dev/null 2>&1 || {
        printf '⛔ GOVERNOR: flock(1) not found on PATH -- cannot serialize heavy windows. Refusing rather than running unguarded.\n' >&2
        return 2
    }
    local dir; dir="$(dirname -- "$GOV_LOCK")"
    if [ ! -d "$dir" ]; then
        printf '⛔ GOVERNOR: semaphore directory missing: %s -- refusing.\n' "$dir" >&2
        return 2
    fi
    if [ -e "$GOV_LOCK" ]; then
        if [ ! -f "$GOV_LOCK" ]; then
            printf '⛔ GOVERNOR: semaphore path exists but is not a regular file: %s -- refusing.\n' "$GOV_LOCK" >&2
            return 2
        fi
        if [ ! -r "$GOV_LOCK" ] || [ ! -w "$GOV_LOCK" ]; then
            printf '⛔ GOVERNOR: semaphore file is not read-write for this user: %s -- refusing.\n' "$GOV_LOCK" >&2
            return 2
        fi
    elif [ ! -w "$dir" ]; then
        printf '⛔ GOVERNOR: semaphore directory not writable, cannot create %s -- refusing.\n' "$GOV_LOCK" >&2
        return 2
    fi
    return 0
}

# _governor_run <shared|exclusive> <try:0|1> <command...> -- acquire+run+release in one subshell so the
# flock (held on the subshell's own fd) is released by the kernel the moment the subshell exits for ANY
# reason, with no manual fd-close bookkeeping and no window where a crash leaks the lock.
_governor_run() {
    local mode="$1" try="$2"; shift 2
    [ "$#" -gt 0 ] || { printf '⛔ GOVERNOR: no command given to wrap (usage: governor_build|governor_bench [--try] -- <command...>)\n' >&2; return 64; }
    _governor_preflight || return 2
    (
        exec {fd}<>"$GOV_LOCK" || exit 2
        local flg=-x
        [ "$mode" = shared ] && flg=-s
        if [ "$try" = 1 ]; then
            flock -n "$flg" "$fd" || exit 3
        else
            flock "$flg" "$fd" || exit 2
        fi
        "$@"
    )
    return $?
}

governor_build() {   # SHARED slot -- many builds may hold this concurrently.
    local try=0
    [ "${1:-}" = "--try" ] && { try=1; shift; }
    [ "${1:-}" = "--" ] && shift
    _governor_run shared "$try" "$@"
}
governor_bench() {   # EXCLUSIVE slot -- excludes every build and every other benchmark until it releases.
    local try=0
    [ "${1:-}" = "--try" ] && { try=1; shift; }
    [ "${1:-}" = "--" ] && shift
    _governor_run exclusive "$try" "$@"
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
    case "${1:-}" in
        build|bench) cmd="$1"; shift; governor_"$cmd" "$@"; exit $? ;;
        *) printf 'usage: %s {build|bench} [--try] -- <command...>\n' "$0" >&2; exit 64 ;;
    esac
fi
