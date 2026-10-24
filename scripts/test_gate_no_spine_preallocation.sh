#!/usr/bin/env bash
# test_gate_no_spine_preallocation.sh -- NO SPINE CELL IS ALLOCATED BEFORE ITS BOX (Lon 2026-10-21, in-chat to the ceo, verbatim: "I should see a
# count of pre-allocations and see it go to ZERO. SPINE allocations MUST ONLY be allocated PER BOX and at ALPHA at EACH BOX." · "And sometimes at BETA
# in a BB BOX."; ceo CEO-1855).
# Runs util_bb_placement_census.py over every program of util_spine_population.sh with this root's ./scrip and sums its BB_HOSTS pre-allocations:
# a box granted a frame slot at entry that is not its RBP home (ops_prealloc) + an operand carved at entry (ops_precarved) + a local carved at entry
# that passes both of Lon's tests (loc_rbp_misplaced). The RBP homes, the locals that fail a test and the frame words stay in the frame.
#   test_gate_no_spine_preallocation.sh [--lang L]
# Board line per language and in total: SPINE_PREALLOC_BOARD lang=<l>|total prealloc=<n> slots=<a> carved_operands=<b> carved_locals=<c>
# THE DOCUMENTED FLOOR (the cfo 2026-10-24, CEO-1952): scripts/spine_prealloc_floor.tsv names, per language and box kind, the pre-allocations that are still allowed and may only fall
# (Prolog: 378 DISJUNCTION cells, the admitted non-retaining disjunctions whose frame record waits for the plan-before-layout order); every other pre-allocation, and every one
# of a listed kind above its floor, is red. The board prints prealloc=<n> floor=<f> over=<o>; the gate is rc 0 at over=0.
# rc 0 over=0 (prealloc at or below the floor) · rc 1 a pre-allocation above the floor remains · rc 2 could not measure (the census refused, or printed no BB_HOSTS).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
L=""; [ "${1:-}" = "--lang" ] && L="${2:-}"
[ -x "$ROOT/SCRIP/scrip" ] || { echo "REFUSE(2): no $ROOT/SCRIP/scrip"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
bash "$HERE/util_spine_population.sh" --corpus "$ROOT/corpus" ${L:+--lang "$L"} | cut -f2 > "$T/files" || { echo "REFUSE(2): no population"; exit 2; }
[ -s "$T/files" ] || { echo "REFUSE(2): the population is empty${L:+ for $L}"; exit 2; }
( cd "$ROOT/SCRIP" && env -u S4E_HOME python3 "$HERE/util_bb_placement_census.py" --files $(cat "$T/files") --cells "$T/cells" ) > "$T/out" 2>/dev/null; rc=$?
[ "$rc" = 0 ] || { grep '^BB_PLACEMENT REFUSE' "$T/out"; echo "REFUSE(2): the census did not measure (rc $rc)"; exit 2; }
grep -q '^BB_HOSTS ' "$T/out" || { echo "REFUSE(2): the census printed no BB_HOSTS"; exit 2; }
python3 - "$T/out" "$(git -C "$ROOT/SCRIP" rev-parse --short HEAD)" "$T/cells" "${S4E_PREALLOC_FLOOR_FILE:-$HERE/spine_prealloc_floor.tsv}" <<'PY'
import sys, collections
out, tree, cells, floorf = sys.argv[1:5]
floor = {}
try:
    for ln in open(floorf, encoding='utf-8'):
        if ln.startswith('#') or not ln.strip(): continue
        f = ln.rstrip('\n').split('\t'); floor[(f[0], f[1])] = int(f[2])
except OSError:
    pass
kinds = collections.defaultdict(collections.Counter)
try:
    for ln in open(cells, encoding='utf-8'):
        f = ln.rstrip('\n').split('\t')
        if len(f) >= 8 and f[2] == 'prealloc': kinds[f[0]][f[7]] += 1
except OSError:
    pass
tot = [0, 0, 0, 0, 0]
for ln in open(out, encoding='utf-8'):
    if ln.startswith('BB_HOSTS '):
        p = ln.split(); v = dict(x.split('=') for x in p[2:]); lang = p[1]
        a, b, c = int(v.get('ops_prealloc', 0)), int(v['ops_precarved']), int(v['loc_rbp_misplaced'])
        allowed = sum(min(n, floor.get((lang, k), 0)) for k, n in kinds[lang].items())
        over = (a - allowed) + b + c
        print('SPINE_PREALLOC_BOARD lang=%s prealloc=%d slots=%d carved_operands=%d carved_locals=%d floor=%d over=%d%s' % (lang, a + b + c, a, b, c, allowed, over,
              ' by_kind=' + ','.join('%s:%d' % kn for kn in sorted(kinds[lang].items())) if kinds[lang] else ''))
        for (fl, fk), fv in floor.items():
            if fl == lang and kinds[lang].get(fk, 0) < fv: print('SPINE_PREALLOC_FLOOR_CAN_DROP lang=%s kind=%s floor=%d now=%d -- lower scripts/spine_prealloc_floor.tsv' % (lang, fk, fv, kinds[lang].get(fk, 0)))
        tot = [tot[0] + a, tot[1] + b, tot[2] + c, tot[3] + allowed, tot[4] + over]
print('SPINE_PREALLOC_BOARD total prealloc=%d slots=%d carved_operands=%d carved_locals=%d floor=%d over=%d (tree %s)' % (tot[0] + tot[1] + tot[2], tot[0], tot[1], tot[2], tot[3], tot[4], tree))
open(out + '.total', 'w').write(str(tot[4]))
PY
n="$(cat "$T/out.total")"
[ "$n" = 0 ] && { echo "GATE OK [test_gate_no_spine_preallocation]: no spine cell allocated before its box beyond the documented floor"; exit 0; }
echo "GATE FAIL [test_gate_no_spine_preallocation]: $n pre-allocation(s) above the documented floor"; exit 1
