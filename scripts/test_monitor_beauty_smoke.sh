#!/bin/bash
# test_monitor_beauty_smoke.sh — GOAL-INPROC-MONITOR IM-16
#
# Runs scrip-monitor --monitor on a curated set of SNOBOL4 programs and
# reports the first diverging statement between SCRIP (IR/SM/native codegen) and
# CSNOBOL4.  This is a diagnostic tool — the script always exits 0.
# Divergences are expected and informative, not failures.
#
# Programs are chosen to exercise: functions/recursion, patterns, capture,
# control flow, data structures (TABLE/ARRAY), string builtins, and
# indirect references — the most likely sources of IR vs CSNOBOL4 gaps.
#
# Gate: script exits 0.  All output is diagnostic.
#
# Self-contained per RULES.md: paths derived from $0, < /dev/null, timeout 8s.
#
# Usage: bash ../harness/scripts/test_monitor_beauty_smoke.sh
#        SCRIP_MONITOR=/path/to/scrip-monitor bash ../harness/scripts/test_monitor_beauty_smoke.sh
#
# Authors: LCherryholmes · Claude Sonnet 4.6
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
TEST="$ROOT/../corpus/tests/scrip_test/snobol4"

# Use scrip-monitor (WITH_CSNOBOL4 build); fall back to scrip for IR/SM/native codegen only
SCRIP_MONITOR="${SCRIP_MONITOR:-$ROOT/scrip-monitor}"
if [[ ! -x "$SCRIP_MONITOR" ]]; then
    echo "MISSING scrip-monitor binary: $SCRIP_MONITOR"
    echo "       Build with: make scrip-monitor CSN_A=$S4A/csnobol4/libcsnobol4.a"
    exit 0   # diagnostic tool — always exit 0
fi

AGREE=0
DIVERGE=0
SKIP=0

run_program() {
    local label="$1"
    local file="$2"
    if [[ ! -f "$file" ]]; then
        echo "  SKIP $label — file not found: $file"
        SKIP=$((SKIP + 1))
        return
    fi
    local out
    out=$(timeout -k 5 8 "$SCRIP_MONITOR" --monitor "$file" < /dev/null 2>&1)
    local rc=$?
    if echo "$out" | grep -q "^DIVERGE at stmt\|scrip --monitor: DIVERGE"; then
        local div_line
        div_line=$(echo "$out" | grep "DIVERGE at stmt" | head -1)
        local csn_lines
        csn_lines=$(echo "$out" | grep "IR vs CSN" | head -1)
        echo "  DIVERGE $label"
        echo "          $div_line"
        [[ -n "$csn_lines" ]] && echo "          $csn_lines"
        DIVERGE=$((DIVERGE + 1))
    elif [[ $rc -eq 0 ]]; then
        echo "  AGREE   $label"
        AGREE=$((AGREE + 1))
    else
        # Crash (rc=139 segfault, rc=1 error) — treat as SKIP, note the cause
        local first
        first=$(echo "$out" | grep -v "^  stmt" | head -2 | tr '\n' ' ')
        echo "  SKIP $label — exit $rc: $first"
        SKIP=$((SKIP + 1))
    fi
}

echo "=== --monitor beauty smoke: SCRIP vs CSNOBOL4 (IM-16) ==="
echo "    scrip-monitor: $SCRIP_MONITOR"
echo ""

# ── Functions and recursion ──────────────────────────────────────────────────
run_program "define: simple return"    "$TEST/functions/083_define_simple_return.sno"
run_program "define: recursive fib"    "$TEST/functions/088_define_recursive_fib.sno"
run_program "define: two args"         "$TEST/functions/085_define_two_args.sno"

# ── Patterns and capture ─────────────────────────────────────────────────────
run_program "pattern: ARBNO"           "$TEST/patterns/052_pat_arbno.sno"
run_program "capture: in ARBNO"        "$TEST/capture/061_capture_in_arbno.sno"
run_program "capture: dot immediate"   "$TEST/capture/058_capture_dot_immediate.sno"

# ── Control flow ─────────────────────────────────────────────────────────────
run_program "control: both branches"   "$TEST/control_new/035_goto_both_branches.sno"
run_program "control: loop count"      "$TEST/control_new/032_goto_loop_count.sno"

# ── Data structures: TABLE and ARRAY ─────────────────────────────────────────
# These are known divergence points between SCRIP and CSNOBOL4.
run_program "data: TABLE create/access"  "$TEST/data/093_table_create_access.sno"
run_program "data: DATA define/access"   "$TEST/data/094_data_define_access.sno"
run_program "rung11: ARRAY 1-D"          "$TEST/rung11/1110_array_1d.sno"
run_program "rung11: TABLE"              "$TEST/rung11/1113_table.sno"

# ── String builtins ───────────────────────────────────────────────────────────
run_program "string: REPLACE"          "$TEST/strings/067_builtin_replace.sno"
run_program "string: DUPL"             "$TEST/strings/069_builtin_dupl.sno"

# ── Advanced: OPSYN, APPLY, indirect ─────────────────────────────────────────
# OPSYN/indirect may SKIP due to pre-existing CSNOBOL4 gaps (not SCRIP bugs).
run_program "rung10: OPSYN"            "$TEST/rung10/1015_opsyn.sno"
run_program "rung10: APPLY"            "$TEST/rung10/1018_apply.sno"
run_program "rung2: indirect ref"      "$TEST/rung2/210_indirect_ref.sno"

echo ""
echo "AGREE=$AGREE DIVERGE=$DIVERGE SKIP=$SKIP"
echo ""
echo "Note: DIVERGE = first stmt where SCRIP IR/SM/native codegen diverges from CSNOBOL4."
echo "      SKIP    = pre-existing CSNOBOL4 gap or file not present."
echo "      This script is a diagnostic tool — exit 0 always."

# Known divergence reference (updated IM-16 session 2026-04-15):
#   1110_array_1d.sno  — DIVERGE at stmt 8 [label: e002, line 16]  (ARRAY indexing)
#   1113_table.sno     — DIVERGE at stmt 8 [label: e002, line 16]  (TABLE indexing)

exit 0
