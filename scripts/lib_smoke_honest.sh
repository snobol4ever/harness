#!/usr/bin/env bash
# lib_smoke_honest.sh -- A SMOKE STEP KILLED BY ITS TIMEOUT IS A TIMEOUT, NOT A WRONG ANSWER; UNDER OVERLOAD IT REFUSES (ceo CEO-2081, 2026-10-31, on the
# coo's polyglot tier-1 red at 96f4dbfc6: at load 53 to 55 the ceo's clean origin run read all four polyglot cases red with empty output, while by hand
# the tri-fence witness ran correctly in 6.86 s against the runner's fixed 8 s timeout; "a false red under load sends a lane to revert innocent work").
# Sourced by a smoke runner. After each timed step the runner calls smoke_note <rc> in its own shell (not inside $(...), whose counters are lost):
#   rc 124 or 137 (timeout's TERM or KILL) counts a TIMEOUT and records load1 at that moment; smoke_note returns 0 for a timeout, 1 otherwise, so
#   the runner prints "TIMEOUT" in place of the wrong answer it would have shown.
# At the end the runner calls smoke_finish <fail-count>: when any step timed out while load1 was over SMOKE_LOAD_FACTOR (2) x cores the runner
# REFUSES rc 2 (CEO-1680: a test that cannot measure refuses, never reds); otherwise rc 1 on a failure (a timeout on a quiet box is a red), rc 0 green.
# SMOKE_LOADAVG (default /proc/loadavg) and SMOKE_CORES (default nproc) are the fixture's seams.
SMOKE_TIMEOUTS=0; SMOKE_TIMEOUTS_LOADED=0; SMOKE_TIMEOUT_LOADS=""
smoke_note() {
  case "$1" in 124|137) ;; *) return 1;; esac
  local l c; l=$(cut -d' ' -f1 "${SMOKE_LOADAVG:-/proc/loadavg}" 2>/dev/null); c=${SMOKE_CORES:-$(nproc 2>/dev/null || echo 1)}
  SMOKE_TIMEOUTS=$((SMOKE_TIMEOUTS + 1)); SMOKE_TIMEOUT_LOADS="$SMOKE_TIMEOUT_LOADS ${l:-?}"
  awk -v l="${l:-0}" -v c="$c" -v f="${SMOKE_LOAD_FACTOR:-2}" 'BEGIN { exit !(l > f * c) }' && SMOKE_TIMEOUTS_LOADED=$((SMOKE_TIMEOUTS_LOADED + 1))
  return 0
}
smoke_finish() {
  local c; c=${SMOKE_CORES:-$(nproc 2>/dev/null || echo 1)}
  if [ "$SMOKE_TIMEOUTS_LOADED" -gt 0 ]; then
    echo "SMOKE REFUSE(2): $SMOKE_TIMEOUTS_LOADED of $SMOKE_TIMEOUTS timed-out step(s) ran while load1 was over ${SMOKE_LOAD_FACTOR:-2} x $c cores (load1 at each timeout:$SMOKE_TIMEOUT_LOADS) -- the box cannot measure this smoke now; re-run when it is quieter (CEO-1680, CEO-2081)"
    exit 2
  fi
  [ "$SMOKE_TIMEOUTS" -gt 0 ] && echo "SMOKE: $SMOKE_TIMEOUTS step(s) timed out at load1$SMOKE_TIMEOUT_LOADS, under ${SMOKE_LOAD_FACTOR:-2} x $c cores -- counted as failures"
  [ "${1:-0}" -eq 0 ] || exit 1
  exit 0
}
# THE FILE-BACKED FORM for a runner whose steps run inside $(...) (CEO-2081 rollout to the eight fleet smokes): smoke_t takes timeout's own arguments
# and runs it; a step it kills (124 or 137) prints TIMEOUT as the step's output, so a case shows "got: TIMEOUT", never an empty wrong answer, and its
# load1 lands in SMOKE_TO_FILE, which a subshell can write. smoke_refuse_if_loaded, called just before the runner's own verdict, exits 2 when any timeout
# fell over SMOKE_LOAD_FACTOR x cores and otherwise returns 0 and leaves the verdict to the runner.
SMOKE_TO_FILE="$(mktemp "${TMPDIR:-/tmp}/smoke_to.XXXXXX")"; trap 'rm -f "$SMOKE_TO_FILE"' EXIT
smoke_t() {
  timeout "$@"; local rc=$?
  case "$rc" in 124|137) cut -d' ' -f1 "${SMOKE_LOADAVG:-/proc/loadavg}" 2>/dev/null >> "$SMOKE_TO_FILE"; echo TIMEOUT;; esac
  return "$rc"
}
smoke_refuse_if_loaded() {
  local c n k loads; c=${SMOKE_CORES:-$(nproc 2>/dev/null || echo 1)}
  n=$(grep -c . "$SMOKE_TO_FILE" 2>/dev/null); n=${n:-0}; [ "$n" -gt 0 ] || return 0
  k=$(awk -v c="$c" -v f="${SMOKE_LOAD_FACTOR:-2}" '$1 + 0 > f * c {k++} END {print k + 0}' "$SMOKE_TO_FILE"); loads=$(paste -sd' ' "$SMOKE_TO_FILE")
  if [ "$k" -gt 0 ]; then
    echo "SMOKE REFUSE(2): $k of $n timed-out step(s) ran while load1 was over ${SMOKE_LOAD_FACTOR:-2} x $c cores (load1 at each timeout: $loads) -- the box cannot measure this smoke now; re-run when it is quieter (CEO-1680, CEO-2081)"
    exit 2
  fi
  echo "SMOKE: $n step(s) timed out at load1 $loads, under ${SMOKE_LOAD_FACTOR:-2} x $c cores -- counted as failures"
  return 0
}
