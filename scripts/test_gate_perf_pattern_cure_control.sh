#!/usr/bin/env bash
# test_gate_perf_pattern_cure_control.sh — DONE-WHEN gate for row perf-pattern-defer-capture-layer-cure.
# D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; S4E_HOME overrides).
#
# ⛔⭐ WHY THIS EXISTS AS A SCRIPT AND WHAT IT FIXED (hq_P 2026-08-29, on seat06's q-hq_P):
# The row's inline DONE-WHEN asserted one thing — pattern_bt m4 insn/iter < 3000 — and that bar is
# ALREADY MET ON THE UNCURED TREE. Measured: with this row's cure (SCRIP 8d944ead) reverted, pattern_bt
# m4 reads 2231 insn/iter; with it, 2232. The gate returned rc=0 for BOTH. So it graded "has the tree
# improved since the 2026-08-27 baseline", never "did THIS cure do anything" — a vacuous cure gate.
# The cure is what the row is for, so the gate must compare the cure against ITS OWN CONTROL ARM.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
BENCH="$S4E/corpus/benchmarks/snobol4"
BASELINE="perf-attribution-20260827T233658Z.tsv"
MAX_INSN_PER_ITER="${MAX_INSN_PER_ITER:-3000}"
MIN_CURE_DELTA_PCT="${MIN_CURE_DELTA_PCT:-1.0}"

[ -d "$BENCH" ] || { echo "REFUSE (rc=2): cannot resolve $BENCH -- cannot measure, not a pass"; exit 2; }
cd "$BENCH" || exit 2

# newest-first, pick the newest TSV that actually carries all three required row kinds.
# (hq_C s278 lesson: a selector answering "which is newest" must not be read as "which is the one I mean".)
sel=""
for f in $(ls -t perf-attribution-2*.tsv 2>/dev/null); do
    [ "$f" = "$BASELINE" ] && continue
    awk -F'\t' '$1=="pattern_bt"&&$2=="m4"{a=1} $1=="string_pattern"{b=1} $2=="m4_precure"{c=1} END{exit !(a&&b&&c)}' "$f" || continue
    sel="$f"; break
done
[ -n "$sel" ] && { echo "REFUSE (rc=2): no dated TSV carries pattern_bt/m4 AND string_pattern AND an m4_precure CONTROL ARM." >/dev/null; } || {
    echo "REFUSE (rc=2): no dated TSV besides the baseline carries pattern_bt/m4 AND string_pattern AND an m4_precure CONTROL ARM."
    echo "  A cure gate without a control arm cannot tell the cure from the tree. Append one; do not lower this bar."
    exit 2; }

echo "gate: perf-pattern-defer-capture-layer-cure  TSV=$sel"
awk -F'\t' -v F="$sel" -v MAX="$MAX_INSN_PER_ITER" -v MIND="$MIN_CURE_DELTA_PCT" '
  $1=="pattern_bt" && $2=="m4"        { split($5,a,"("); cur=a[1]+0; s1=1 }
  $1=="pattern_bt" && $2=="m4_precure"{ split($5,a,"("); pre=a[1]+0; s2=1 }
  END {
    if (!s1 || !s2) { printf "REFUSE (rc=2): %s lacks a pattern_bt m4 or m4_precure row -- criterion cannot measure\n", F; exit 2 }
    if (pre <= 0)   { printf "REFUSE (rc=2): m4_precure control reads %d -- cannot compute a delta\n", pre; exit 2 }
    if (cur > MAX)  { printf "FAIL: pattern_bt m4 insn/iter %d still above %d in %s\n", cur, MAX, F; exit 1 }
    d = (pre - cur) / pre * 100.0
    if (d < MIND) {
      printf "FAIL: THE CURE IS INERT -- pattern_bt m4 %d vs its own m4_precure control %d = %.3f%% (< %.1f%%, inside this box'\''s ~0.01%% noise).\n", cur, pre, d, MIND
      printf "      The %d bar is met on the UNCURED tree too, so passing it grades the TREE, not this row.\n", MAX
      exit 1
    }
    printf "GATE OK: pattern_bt m4 %d insn/iter (<= %d) AND %.2f%% better than its own m4_precure control, in %s\n", cur, MAX, d, F
  }' "$sel"
