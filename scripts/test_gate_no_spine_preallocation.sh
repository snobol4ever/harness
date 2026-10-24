#!/usr/bin/env bash
# test_gate_no_spine_preallocation.sh -- NO SPINE CELL IS ALLOCATED BEFORE ITS BOX (Lon 2026-10-21, in-chat to the ceo, verbatim: "I should see a
# count of pre-allocations and see it go to ZERO. SPINE allocations MUST ONLY be allocated PER BOX and at ALPHA at EACH BOX." · "And sometimes at BETA
# in a BB BOX."; ceo CEO-1855).
# Runs util_bb_placement_census.py over every program of util_spine_population.sh with this root's ./scrip and sums its BB_HOSTS pre-allocations:
# a box granted a frame slot at entry that is not its RBP home (ops_prealloc) + an operand carved at entry (ops_precarved) + a local carved at entry
# that passes both of Lon's tests (loc_rbp_misplaced). The RBP homes, the locals that fail a test and the frame words stay in the frame.
#   test_gate_no_spine_preallocation.sh [--lang L]
# Board line per language and in total: SPINE_PREALLOC_BOARD lang=<l>|total prealloc=<n> slots=<a> carved_operands=<b> carved_locals=<c>
# rc 0 prealloc=0 · rc 1 a pre-allocation remains · rc 2 could not measure (the census refused, or printed no BB_HOSTS).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
L=""; [ "${1:-}" = "--lang" ] && L="${2:-}"
[ -x "$ROOT/SCRIP/scrip" ] || { echo "REFUSE(2): no $ROOT/SCRIP/scrip"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
bash "$HERE/util_spine_population.sh" --corpus "$ROOT/corpus" ${L:+--lang "$L"} | cut -f2 > "$T/files" || { echo "REFUSE(2): no population"; exit 2; }
[ -s "$T/files" ] || { echo "REFUSE(2): the population is empty${L:+ for $L}"; exit 2; }
( cd "$ROOT/SCRIP" && env -u S4E_HOME python3 "$HERE/util_bb_placement_census.py" --files $(cat "$T/files") ) > "$T/out" 2>/dev/null; rc=$?
[ "$rc" = 0 ] || { grep '^BB_PLACEMENT REFUSE' "$T/out"; echo "REFUSE(2): the census did not measure (rc $rc)"; exit 2; }
grep -q '^BB_HOSTS ' "$T/out" || { echo "REFUSE(2): the census printed no BB_HOSTS"; exit 2; }
python3 - "$T/out" "$(git -C "$ROOT/SCRIP" rev-parse --short HEAD)" <<'PY'
import sys
tot = [0, 0, 0]
for ln in open(sys.argv[1], encoding='utf-8'):
    if ln.startswith('BB_HOSTS '):
        p = ln.split(); v = dict(x.split('=') for x in p[2:])
        a, b, c = int(v.get('ops_prealloc', 0)), int(v['ops_precarved']), int(v['loc_rbp_misplaced'])
        print('SPINE_PREALLOC_BOARD lang=%s prealloc=%d slots=%d carved_operands=%d carved_locals=%d' % (p[1], a + b + c, a, b, c))
        tot = [tot[0] + a, tot[1] + b, tot[2] + c]
print('SPINE_PREALLOC_BOARD total prealloc=%d slots=%d carved_operands=%d carved_locals=%d (tree %s)' % (sum(tot), tot[0], tot[1], tot[2], sys.argv[2]))
open(sys.argv[1] + '.total', 'w').write(str(sum(tot)))
PY
n="$(cat "$T/out.total")"
[ "$n" = 0 ] && { echo "GATE OK [test_gate_no_spine_preallocation]: no spine cell allocated before its box"; exit 0; }
echo "GATE FAIL [test_gate_no_spine_preallocation]: $n pre-allocation(s)"; exit 1
