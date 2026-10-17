#!/usr/bin/env bash
# lib_pristine_lock.sh -- row `build-governor-holds-pristine-while-box-idles`. Bounded-wait wrapper
# around the per-root pristine BUILD_LOCK (make-pristine-per-root-flock-second-builder-waits). Replaces
# the Makefile's old `flock $(BUILD_LOCK) -c '...'`'s UNBOUNDED, SILENT blocking wait with a bounded one
# that REFUSES LOUDLY -- naming the current holder -- instead of hanging. hq_P lost ~9.5h overnight
# (22:05->07:41) to exactly this shape: a hold that is, from the waiting seat's side, indistinguishable
# from a slow build. REPRODUCED under CONTROL before this cure existed: an artificial holder that does
# nothing but `sleep` (0.0% CPU for its whole 30s hold, confirmed via `ps`) blocked `make pristine` just
# as completely as a real compile would -- the old mechanism cannot tell a HELD build from a SLOW one
# because it has no concept of "wait, but not forever" and prints nothing while waiting.
#
# ⛔ THE MUTUAL EXCLUSION ITSELF IS UNCHANGED -- this does not touch why the lock exists (two `make
# pristine` in one root racing the same `rm -rf`, see make-pristine-per-root-flock-second-builder-waits).
# A normal, healthy build still acquires near-instantly and behaves byte-identically to before. The ONLY
# behavior change is what happens after waiting past the bound for the SAME lock: silently-wait-forever
# becomes bounded-wait-then-loud-refusal, matching this codebase's own refuse-not-repair idiom used
# elsewhere (lib_build_governor.sh's _governor_preflight, util_verify_s_artifacts_owed.sh).
#
# WHY A SEPARATE SCRIPT, NOT INLINED INTO THE MAKEFILE RECIPE: the Makefile recipe shell is not
# guaranteed to be bash (POSIX $(SHELL), often dash), and this needs bash's `{fd}<>` automatic fd
# allocation to hold the lock open across a probe-then-wait sequence without racing itself. Invoked
# directly via `bash ../harness/scripts/lib_pristine_lock.sh ...` from the recipe, sidestepping the question.
#
# USAGE: bash ../harness/scripts/lib_pristine_lock.sh <lockfile> -- <command...>
# EXIT CODE CONTRACT (mirrors lib_build_governor.sh's shape so the two are read the same way):
#   98  couldn't even open the lockfile (bad path/permissions) -- the wrapped command NEVER RAN.
#   99  wait exceeded S4E_PRISTINE_LOCK_TIMEOUT (default 1200s, override for a legitimately slower box)
#       -- the wrapped command NEVER RAN. stderr names the current holder's PID + cmdline first.
#   64  usage error (no command given to wrap).
#   *   any other code is the WRAPPED COMMAND's own exit status, passed through verbatim.
# 1200s (20min) is chosen well above any observed real -O0 pristine build (~1m40 quiet-box, single
# digit minutes even under heavy fleet contention per seat04's 748s FULL-CORPUS-BOARD measurement,
# which is a much heavier operation than one pristine) and far below "hours" -- generous enough to
# never trip a legitimately-slow-but-live build, bounded enough to turn a multi-hour silent hang into
# an actionable refusal within one sitting.
set -uo pipefail

LOCK="${1:?usage: lib_pristine_lock.sh <lockfile> -- <command...>}"; shift
[ "${1:-}" = "--" ] && shift
[ "$#" -gt 0 ] || { printf '⛔ PRISTINE-LOCK: no command given to wrap (usage: lib_pristine_lock.sh <lockfile> -- <command...>)\n' >&2; exit 64; }

TIMEOUT="${S4E_PRISTINE_LOCK_TIMEOUT:-1200}"

# describe_pid <pid> <label> -- one PID rendered as "<label> <pid> (running Ns): cmdline".
describe_pid() {
    local p="$1" label="$2"
    if [ -r "/proc/$p/cmdline" ]; then
        printf '%s %s (running %ss): %s\n' "$label" "$p" \
            "$(ps -o etimes= -p "$p" 2>/dev/null | tr -d ' ')" \
            "$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)"
    else
        printf '%s %s (already exited)\n' "$label" "$p"
    fi
}
# describe_holder -- who holds $LOCK's flock right now. PRECISE when possible: /proc/locks carries the
# actual WRITE-lock-holding PID per inode (no ambiguity), which fuser cannot give -- fuser only reports
# who has the FILE open, and this script's own waiting side ALSO has it open (via `exec {fd}<>`) without
# holding the lock, so a fuser-only reading would misreport an innocent waiter as a holder. Falls back to
# fuser only if /proc/locks is unavailable (e.g. a sandboxed environment that hides it), labeled as such
# so the fallback's lower precision is visible rather than silently passed off as exact.
describe_holder() {
    local ino; ino="$(stat -c '%i' "$LOCK" 2>/dev/null)"
    if [ -n "$ino" ] && [ -r /proc/locks ]; then
        # $2=="FLOCK" excludes "N: -> FLOCK ..." continuation lines (a BLOCKED WAITER's own entry,
        # shifted one field right by the "->") -- without this a waiter can misreport as a holder.
        local pids; pids="$(awk -v ino="$ino" '$2=="FLOCK" && $4=="WRITE" && $6 ~ ":" ino "$" {print $5}' /proc/locks | sort -u)"
        if [ -n "$pids" ]; then
            local p; for p in $pids; do describe_pid "$p" "holder pid"; done
            return
        fi
    fi
    local pids; pids="$(fuser "$LOCK" 2>/dev/null | tr -s ' \t' '\n' | grep -E '^[0-9]+$' || true)"
    if [ -z "$pids" ]; then
        printf '(no holder visible -- it may have just released)\n'
        return
    fi
    printf '(fuser fallback -- lists everyone with the file open, not only the lock holder)\n'
    local p; for p in $pids; do describe_pid "$p" "pid"; done
}

(
    exec {fd}<>"$LOCK" || exit 98
    if ! flock -n "$fd" 2>/dev/null; then
        printf '⏳ PRISTINE-LOCK: %s is held -- waiting up to %ss (override with S4E_PRISTINE_LOCK_TIMEOUT=<seconds>). Current holder:\n' "$LOCK" "$TIMEOUT" >&2
        describe_holder | sed 's/^/    /' >&2
        if ! flock -w "$TIMEOUT" "$fd" 2>/dev/null; then
            printf '⛔ PRISTINE-LOCK REFUSED: still held after %ss -- refusing rather than hanging silently (this row exists because a silent hold cost ~9.5h once, unnoticed until it self-cleared). Current holder:\n' "$TIMEOUT" >&2
            describe_holder | sed 's/^/    /' >&2
            printf '    If this is a genuinely slow build, not a stuck one, re-run with S4E_PRISTINE_LOCK_TIMEOUT=<seconds> to raise the bound.\n' >&2
            exit 99
        fi
        printf '✅ PRISTINE-LOCK: acquired %s after waiting.\n' "$LOCK" >&2
    fi
    "$@"
)
exit $?
