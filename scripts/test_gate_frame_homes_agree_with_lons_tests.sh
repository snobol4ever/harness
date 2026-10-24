#!/usr/bin/env bash
# test_gate_frame_homes_agree_with_lons_tests.sh -- EVERY RBP HOME IS ONE LON'S TEST FORCES, AND EVERY OPERAND IT FORCES HAS ONE (Lon 2026-10-21,
# in-chat to the ceo, verbatim: "Will we get all the proper allocations on the RSP spine?" -- and 2026-10-14: "if a BB operand can not be reached
# by fixed RSP offset ... ONLY these two cases go to an RBP ACTIVATION FRAME. ALL the rest/remaining must be RSP SPINE CELLS."; ceo CEO-1865).
# Runs util_bb_placement_census.py over every program of util_spine_population.sh with this root's ./scrip and sums its BB_PLACEMENT_FRAMEHOME
# lines: home_without_test (the compiler homes an operand on RBP where the census's operand path test passes -- an improper RBP allocation, or
# the test's gap) + test_without_home (the path test fails and the compiler homes nothing -- a fixed-offset read the census cannot see, or a
# defect). Until the census's path test is calibrated class by class (CEO-1865), a disagreement is the ceo's to adjudicate, never a verdict.
#   test_gate_frame_homes_agree_with_lons_tests.sh [--lang L]
# Board line per language and in total: FRAME_HOME_AGREE_BOARD lang=<l>|total disagree=<n> homes=<h> agree=<a> home_without_test=<x> test_without_home=<y>
# rc 0 disagree=0 · rc 1 a disagreement remains · rc 2 could not measure (the census refused, or printed no BB_PLACEMENT_FRAMEHOME).
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
grep -q '^BB_PLACEMENT_FRAMEHOME ' "$T/out" || { echo "REFUSE(2): the census printed no BB_PLACEMENT_FRAMEHOME"; exit 2; }
python3 - "$T/out" "$(git -C "$ROOT/SCRIP" rev-parse --short HEAD)" <<'PY'
import sys
tot = [0, 0, 0, 0, 0]
for ln in open(sys.argv[1], encoding='utf-8'):
    if ln.startswith('BB_PLACEMENT_FRAMEHOME '):
        p = ln.split(); v = dict(x.split('=') for x in p[2:])
        h, a, x, y, r = int(v['homes']), int(v['agree']), int(v['home_without_test']), int(v['test_without_home']), int(v.get('ruled', 0))
        print('FRAME_HOME_AGREE_BOARD lang=%s disagree=%d homes=%d agree=%d ruled=%d home_without_test=%d test_without_home=%d' % (p[1], x + y, h, a, r, x, y))
        tot = [tot[0] + h, tot[1] + a, tot[2] + x, tot[3] + y, tot[4] + r]
    elif ln.startswith('BB_PLACEMENT_FRAMEHOME_RULED '):
        print(ln.strip())
print('FRAME_HOME_AGREE_BOARD total disagree=%d homes=%d agree=%d ruled=%d home_without_test=%d test_without_home=%d (tree %s)' % (tot[2] + tot[3], tot[0], tot[1], tot[4], tot[2], tot[3], sys.argv[2]))
open(sys.argv[1] + '.total', 'w').write(str(tot[2] + tot[3]))
PY
n="$(cat "$T/out.total")"
[ "$n" = 0 ] && { echo "GATE OK [test_gate_frame_homes_agree_with_lons_tests]: every RBP home is one the path test forces or one the ceo ruled right by the planner's own fact (CEO-1949), and every forced operand has one"; exit 0; }
echo "GATE FAIL [test_gate_frame_homes_agree_with_lons_tests]: $n disagreement(s) between the compiler's RBP homes and the path test"; exit 1
