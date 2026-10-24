#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_zeta_no_arena.sh — RUNG ZS completion gate (GOAL-SNOBOL4-BB.md, Lon directive 2026-07-14 s57).
# PASS iff ZERO arena zeta events across the set: ZLS2 pushes == 0 (main frame, ZS-1) AND
# ZLS v1 allocs == 0 (DEFER blocks, ZS-2). Mode-3; the runtime .so is shared, so m4 rides the same sinks.
# Prints a per-file table either way; exit 0 = ZS storage goal met, exit 1 = events remain (counts shown).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
SCRIP="${SCRIP:-$(dirname "$0")/../../SCRIP/scrip}"
CORP="${CORP:-$S4E/corpus/benchmarks/snobol4}"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT INT TERM
cat > "$W/defer_probe.sno" <<'EOF'
    N = 3
    P = LEN(*N) . V
    'abcdef' ? P
    OUTPUT = V
END
EOF
FILES="$W/defer_probe.sno"
for b in arith_loop fibonacci pattern_bt roman string_concat func_call; do
    [ -f "$CORP/$b.sno" ] && FILES="$FILES $CORP/$b.sno"
done
total2=0; total1=0
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "${SCRIP:-${SCRIP_BIN:-$(dirname "$0")/../../SCRIP/scrip}}" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
printf "%-24s %10s %14s %12s\n" "program" "zls2_push" "zls2_bytes" "zls1_allocs"
for f in $FILES; do
    out=$(SCRIP_ZETA_TELEM=1 SCRIP_ZLS2_TRACE=1 timeout -k 5 60s "$SCRIP" --run "$f" < /dev/null 2>&1)
    p2=$(printf '%s\n' "$out" | grep -c '^\[ZLS2\] PUSH')
    b2=$(printf '%s\n' "$out" | awk '/^\[ZLS2\] PUSH/ {s+=$3} END {print s+0}')
    a1=$(printf '%s\n' "$out" | sed -n 's/.*allocs=\([0-9]*\).*/\1/p' | head -1); a1=${a1:-0}
    printf "%-24s %10s %14s %12s\n" "$(basename "$f")" "$p2" "$b2" "$a1"
    total2=$((total2 + p2)); total1=$((total1 + a1))
done
rm -rf "$W"
echo "----"
if [ "$total2" -eq 0 ] && [ "$total1" -eq 0 ]; then echo "GATE PASS: zero arena zeta events (ZLS2=0, ZLS1=0)"; exit 0
else echo "GATE FAIL: ZLS2 pushes=$total2 ZLS1 allocs=$total1 (ZS incomplete)"; exit 1; fi
