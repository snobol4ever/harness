#!/usr/bin/env bash
# util_pl_rbp_operand_classes.sh -- THE PROLOG RBP OPERANDS BY CLASS, OVER THE WATCH'S POPULATION (ceo CEO-1980; Lon 2026-10-25 19:0x CDT, in-chat
# to the ceo, verbatim: "I suspect that the 13_000+ operands on RBP for Prolog are bogus, so go fix that and get those down to zero. there is no
# reason that the LIFO can not be enforced."). Runs util_bb_placement_census.py over util_spine_population.sh --lang prolog with this root's
# ./scrip (the population and the count the PLACEMENT watch reads) and prints its BB_HOSTS_RBP_CLASS lines and one board line:
#   PL_RBP_BOARD total=<ops_rbp> call-act-word=.. construct-record=.. record-across-excursion=.. operand-across-retaining-edge=.. address-escapes=.. other=.. (tree <scrip>)
#   util_pl_rbp_operand_classes.sh [--class C] [--at-most N]
# With --at-most N the verdict reads the named class (default: the total): rc 0 at or under N, rc 1 over it. rc 2 could not measure.
# A full pass is about six minutes: a DONE-WHEN that runs it is routed by telegram (it outlives assign's 120 s probe).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CLS=""; MAX=""
while [ $# -gt 0 ]; do case "$1" in --class) CLS="$2"; shift 2;; --at-most) MAX="$2"; shift 2;; *) echo "usage: util_pl_rbp_operand_classes.sh [--class C] [--at-most N]" >&2; exit 2;; esac; done
[ -x "$ROOT/SCRIP/scrip" ] || { echo "REFUSE(2): no $ROOT/SCRIP/scrip"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
bash "$HERE/util_spine_population.sh" --corpus "$ROOT/corpus" --lang prolog | cut -f2 > "$T/files" || { echo "REFUSE(2): no population"; exit 2; }
[ -s "$T/files" ] || { echo "REFUSE(2): the Prolog population is empty"; exit 2; }
( cd "$ROOT/SCRIP" && env -u S4E_HOME python3 "$HERE/util_bb_placement_census.py" --files $(cat "$T/files") ) > "$T/out" 2>/dev/null; rc=$?
[ "$rc" = 0 ] || { grep '^BB_PLACEMENT REFUSE' "$T/out"; echo "REFUSE(2): the census did not measure (rc $rc)"; exit 2; }
grep -q '^BB_HOSTS prolog ' "$T/out" || { echo "REFUSE(2): the census printed no BB_HOSTS prolog line"; exit 2; }
grep '^BB_HOSTS_RBP_CLASS prolog ' "$T/out"
python3 - "$T/out" "$(git -C "$ROOT/SCRIP" rev-parse --short HEAD)" "$CLS" "$MAX" <<'PY'
import sys
out, tree, cls, mx = sys.argv[1:5]
c = {}; total = None
for ln in open(out, encoding='utf-8'):
    p = ln.split()
    if ln.startswith('BB_HOSTS_RBP_CLASS prolog '):
        v = dict(x.split('=', 1) for x in p[2:]); c[v['class']] = c.get(v['class'], 0) + int(v['count'])
    elif ln.startswith('BB_HOSTS prolog '):
        total = int(dict(x.split('=', 1) for x in p[2:])['ops_rbp'])
names = ['call-act-word', 'construct-record', 'record-across-excursion', 'operand-across-retaining-edge', 'address-escapes']
other = sum(v for k, v in c.items() if k not in names)
print('PL_RBP_BOARD total=%d %s other=%d (tree %s)' % (total, ' '.join('%s=%d' % (k, c.get(k, 0)) for k in names), other, tree))
if sum(c.values()) != total:
    print('REFUSE(2): the classes sum to %d, ops_rbp reads %d' % (sum(c.values()), total)); sys.exit(2)
if mx == '':
    sys.exit(0)
n = total if cls == '' else (other if cls == 'other' else c.get(cls, 0))
print('PL_RBP_VERDICT %s=%d at-most=%s -> %s' % (cls or 'total', n, mx, 'GREEN' if n <= int(mx) else 'RED'))
sys.exit(0 if n <= int(mx) else 1)
PY
