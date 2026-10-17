#!/usr/bin/env bash
# bake_ird3_baseline.sh — capture behavioral baselines for the IRD-3 sweep gate.
# Usage: bash ../harness/scripts/bake_ird3_baseline.sh <outdir>
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$REPO/scrip"
OUT="${1:?outdir required}"
mkdir -p "$OUT"
run() { local name="$1"; shift; timeout -k 5 300 "$@" > "$OUT/$name.log" 2>&1; echo "rc=$?" >> "$OUT/$name.log"; echo "  $name done"; }
run smoke_icon    bash "$HERE/test_smoke_icon.sh"
run smoke_prolog  bash "$HERE/test_smoke_prolog.sh"
run smoke_snobol4 bash "$HERE/test_smoke_snobol4.sh"
run smoke_raku    bash "$HERE/test_raku_smoke.sh"
# sno per-file interp sweep (PID-agnostic: stdout+rc only)
SNOSWEEP="$OUT/sno_interp_sweep.txt"; : > "$SNOSWEEP"
find "$REPO/test/snobol4" -name '*.sno' | sort | while read -r f; do
    out=$(timeout -k 5 8 "$SCRIP" --run "$f" < /dev/null 2>/dev/null); rc=$?
    printf '%s rc=%d md5=%s\n' "${f#$REPO/}" "$rc" "$(printf '%s' "$out" | md5sum | cut -d' ' -f1)" >> "$SNOSWEEP"
done
echo "  sno_interp_sweep done ($(wc -l < "$SNOSWEEP") files)"
# pascal x5 interp
PASSWEEP="$OUT/pas_interp_sweep.txt"; : > "$PASSWEEP"
for p in boolchain boolassign alias m4wexpr sieve; do
    f="$S4E/corpus/tests/pascal/$p.pas"
    [ -f "$f" ] || { echo "$p MISSING" >> "$PASSWEEP"; continue; }
    out=$(timeout -k 5 16 "$SCRIP" --run "$f" < /dev/null 2>/dev/null); rc=$?
    printf '%s rc=%d md5=%s\n' "$p" "$rc" "$(printf '%s' "$out" | md5sum | cut -d' ' -f1)" >> "$PASSWEEP"
done
echo "  pas_interp_sweep done"
# icon per-file interp sweep over test/icon
ICNSWEEP="$OUT/icn_interp_sweep.txt"; : > "$ICNSWEEP"
find "$REPO/test/icon" -name '*.icn' | sort | while read -r f; do
    out=$(timeout -k 5 8 "$SCRIP" --run "$f" < /dev/null 2>/dev/null); rc=$?
    printf '%s rc=%d md5=%s\n' "${f#$REPO/}" "$rc" "$(printf '%s' "$out" | md5sum | cut -d' ' -f1)" >> "$ICNSWEEP"
done
echo "  icn_interp_sweep done ($(wc -l < "$ICNSWEEP") files)"
# prolog per-file interp sweep over test/prolog
PLSWEEP="$OUT/pl_interp_sweep.txt"; : > "$PLSWEEP"
find "$REPO/test/prolog" -name '*.pl' | sort | while read -r f; do
    out=$(timeout -k 5 8 "$SCRIP" --run "$f" < /dev/null 2>/dev/null); rc=$?
    printf '%s rc=%d md5=%s\n' "${f#$REPO/}" "$rc" "$(printf '%s' "$out" | md5sum | cut -d' ' -f1)" >> "$PLSWEEP"
done
echo "  pl_interp_sweep done ($(wc -l < "$PLSWEEP") files)"
# snocone per-file interp sweep (test/snocone + corpus/crosscheck/snocone)
SCOSWEEP="$OUT/sco_interp_sweep.txt"; : > "$SCOSWEEP"
# ⛔ 2026-08-29 (hq_P, corpus-crosscheck-probe-total-conversion): corpus/crosscheck/snocone is being
# converted to suite pairs under corpus/tests/snocone/crosscheck_*.{sc,ref}. A suite file is NEVER run
# whole, so it cannot join this per-file sweep -- and the old form's bare `2>/dev/null` glob meant a
# shrinking tree contributed fewer rows with NO signal at all (181 -> 20 in one commit). The population
# is now COUNTED and PRINTED, and a zero population REFUSES rather than baking an empty baseline.
SCO_SRCS=$( { find "$REPO/test/snocone" -name '*.sc' 2>/dev/null; find "$S4E/corpus/crosscheck/snocone" -name '*.sc' 2>/dev/null; } | sort )
SCO_N=$(printf '%s\n' "$SCO_SRCS" | grep -c . || true)
echo "  sco_interp_sweep population: $SCO_N loose .sc (converted families are graded as suites by test_invariants_3x3_harness.sh's snocone_x86 cell, not swept here)"
if [ "$SCO_N" -eq 0 ]; then
    echo "  REFUSE (rc=2): sco_interp_sweep found zero loose .sc -- cannot bake a baseline from an empty population" >&2
    exit 2
fi
printf '%s\n' "$SCO_SRCS" | while read -r f; do
    [ -n "$f" ] || continue
    out=$(timeout -k 5 8 "$SCRIP" --run "$f" < /dev/null 2>/dev/null); rc=$?
    printf '%s rc=%d md5=%s\n' "${f#$REPO/}" "$rc" "$(printf '%s' "$out" | md5sum | cut -d' ' -f1)" >> "$SCOSWEEP"
done
echo "  sco_interp_sweep done ($(wc -l < "$SCOSWEEP") files)"
run smoke_rebus   bash "$HERE/test_smoke_rebus.sh"
echo "BASELINE BAKED at $OUT"
