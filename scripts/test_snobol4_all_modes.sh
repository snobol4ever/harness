#!/usr/bin/env bash
# ../harness/scripts/test_snobol4_all_modes.sh — SNOBOL4 mode-4 summary runner (Lon directive 2026-06-06)
# Formerly collected M2/M3/M4. Now mode-4 only.
# Runs every SNOBOL4 test suite and displays a mode-4 progress table.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
export SCRIP

_num() { printf '%s' "$1" | grep -oE '[0-9]+' | head -1; }

run_suite() {
    local label="$1" script="$2"
    local out rc t0 t1
    t0=$SECONDS
    # ⛔ WAS `2>/dev/null || true`: that discarded stderr AND flattened every exit code to 0 via `true`,
    # so a killed/timed-out/refused sub-script was INDISTINGUISHABLE from one that ran and found nothing.
    # The real rc is needed below to tell "unmeasured" from "measured zero" (row a-refusal-reported-in-
    # the-vocabulary-of-a-red-absent-line-read-as-unparseable, seat15/hq_T 2026-09-05).
    out=$(bash "$script" 2>&1); rc=$?
    t1=$SECONDS
    local p4 f4
    p4=$(_num "$(printf '%s\n' "$out" | grep -E 'PASS[=-][0-9]+' | grep -oE 'PASS[=-][0-9]+' | tail -1)")
    f4=$(_num "$(printf '%s\n' "$out" | grep -E 'FAIL[=-][0-9]+' | grep -oE 'FAIL[=-][0-9]+' | tail -1)")
    # ⛔ NEVER `${p4:-0}`/`${f4:-0}`: that used to print a false-clean "PASS=0 FAIL=0" for a suite that
    # was never actually run (killed at a timeout bound, crashed before printing a summary, refused) --
    # the MOST dangerous variant of this defect class, since it looks like a real (vacuous) green rather
    # than visibly wrong. Absence, for any reason, reads UNPROVEN with the real cause, never a number.
    if [ -z "$p4" ] || [ -z "$f4" ]; then
        local why="rc=$rc, no PASS=/FAIL= line found in its output"
        if [ "$rc" -eq 124 ] 2>/dev/null; then why="TIMED OUT (rc=124)"
        elif [ "$rc" -gt 128 ] 2>/dev/null; then why="KILLED by SIG$(kill -l "$((rc-128))" 2>/dev/null || echo "$((rc-128))") (rc=$rc)"
        elif [ "$rc" -eq 2 ] 2>/dev/null; then why="REFUSED (rc=2) -- unproven, not a verdict"
        fi
        printf "  %-42s  M4: UNPROVEN (%s) -- not a 0, unmeasured  %ds\n" "$label" "$why" "$((t1-t0))"
        return
    fi
    printf "  %-42s  M4: PASS=%-4d FAIL=%-4d  %ds\n" \
        "$label" "$p4" "$f4" "$((t1-t0))"
}

T0_ALL=$SECONDS
echo "=== SNOBOL4 — MODE-4 ONLY progress table ==="
echo ""
run_suite "smoke"              "$HERE/test_smoke_snobol4.sh"
run_suite "pat_rung (038-057)" "$HERE/test_snobol4_pat_rung_suite.sh"
run_suite "corpus" "$HERE/test_corpus_snobol4.sh"
echo ""
printf "TOTAL TIME: %ds\n" "$((SECONDS-T0_ALL))"
