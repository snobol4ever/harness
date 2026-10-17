#!/usr/bin/env bash
# board_earn0_set.sh — LOWER seat (GOAL-SN4-HOME-LOWER L-0) acceptance board.
# Runs every corpus/probe/earn0 witness in m3 (and optionally m4), diffs vs the
# oracle-baked .ref, and prints a BY-SET table. Judge BY SET, never by count.
# Usage: bash ../harness/scripts/board_earn0_set.sh [m3|m4|both]
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
TIMEOUT_RETRY="${TIMEOUT_RETRY:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_timeout_retry.sh}"   # every graded timeout is retried once, longer (Lon 2026-10-15, in-chat to the coo: "do a retry with longer timeouts")
set -u
SCRIP_DIR="${SCRIP_DIR:-$S4E/SCRIP}"
# ⭐ RE-POINTED (ceo s283h, probe total-conversion): corpus/probe/earn0 is GONE -- the witnesses live in
# the earn0 + earn02 SUITES (tests/snobol4/probe/) and are materialized here via the harness `extract`
# verb into an assembled dir, so the board's per-witness loop below is unchanged. EARN0= still overrides.
if [ -z "${EARN0:-}" ]; then
  _EA="$(mktemp -d)"; trap 'rm -rf "$_EA"' EXIT
  RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$(dirname "${BASH_SOURCE[0]}")/lib_rungs_extract.sh"   # zero-subfolders cutover: materialize the earn0 families out of THE RUNGS
  rungs_extract_family probe_earn0 "$_EA" || true
  rungs_extract_family probe_earn02 "$_EA" || true
  EARN0="$_EA"
fi
MODE="${1:-m3}"
TMO="${TMO:-8}"
one_shot() {
  local f="$1" mode="$2" ref="$3" out rc
  if [ "$mode" = m3 ]; then
    out="$(cd /tmp && "$TIMEOUT_RETRY" "${TMO}s" "$SCRIP_DIR/scrip" --run "$f" 2>/dev/null < /dev/null)"; rc=$?
  else
    out="$(cd /tmp && "$TIMEOUT_RETRY" "${TMO}s" "$SCRIP_DIR/scrip" --compile "$f" 2>/dev/null < /dev/null)"; rc=$?
  fi
  if   [ ! -f "$ref" ];   then echo "NO-REF"
  elif [ "$rc" -eq 124 ]; then echo "FAIL-hang"
  elif [ "$rc" -eq 139 ]; then echo "FAIL-segv"
  elif [ "$rc" -eq 134 ]; then echo "FAIL-abort"
  elif [ "$out" = "$(cat "$ref")" ]; then echo "PASS"
  else echo "FAIL-silent"; fi
}
# REPEAT>1: a row whose verdict is not constant across runs is FLAKY, and FLAKY is
# reported as such — never as whichever arm came up first. earn0_stored_capture is
# the known member (measured 3xPASS-shape/5xABORT at 52545cbf); a single-shot board
# reports it as a coin flip and silently misleads the next seat.
run_one() {
  local f="$1" mode="$2" base ref v first flaky=0 i
  base="$(basename "$f" .sno)"; ref="$EARN0/$base.ref"
  first="$(one_shot "$f" "$mode" "$ref")"
  for i in $(seq 2 "${REPEAT:-1}"); do
    v="$(one_shot "$f" "$mode" "$ref")"; [ "$v" = "$first" ] || flaky=1
  done
  [ "$flaky" -eq 1 ] && first="FLAKY(${first}/…)"
  printf '%-38s %-4s %s\n' "$base" "$mode" "$first"
}
for m in $( [ "$MODE" = both ] && echo "m3 m4" || echo "$MODE" ); do
  echo "=== earn0 board · mode $m · SCRIP $(cd "$SCRIP_DIR" && git rev-parse --short HEAD) · corpus $(cd "$S4E/corpus" && git rev-parse --short HEAD) ==="
  for f in "$EARN0"/*.sno; do run_one "$f" "$m"; done
done
