#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# BP-9 (ii) trivial-β registry gate: emits the 16-bench snobol4 corpus fresh and verifies every
# driver-registered op's β body is exactly [add rsp,K]* jmp (analyze_jump_redundancy.py --gate).
# Backs flat_trivial_beta (src/emitter/emit.cpp); run after any match-template or hook edit.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
HERE="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
SCRIP="$HERE/scrip"
SRC="${1:-$S4E/corpus/benchmarks/snobol4}"
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
fail=0
for sno in "$SRC"/*.sno; do
  b="$(basename "$sno" .sno)"
  timeout -k 5 30 "$SCRIP" --compile "$sno" > "$W/$b.s" 2>/dev/null </dev/null || { echo "EMIT FAIL: $b"; fail=1; }
done
python3 "$HERE/../harness/scripts/analyze_jump_redundancy.py" --gate "$W/*.s" || fail=1
exit $fail
