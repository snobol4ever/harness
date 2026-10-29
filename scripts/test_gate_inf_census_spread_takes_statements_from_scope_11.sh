#!/usr/bin/env bash
# ../harness/scripts/test_gate_inf_census_spread_takes_statements_from_scope_11.sh -- the coverage census counts statement lines from scope 11:
# its spread gains the closed world's statement walk (kind=stmt, preset 3, walk random, limit 12) at --scope 11 and above, and is the six
# configurations it was below that, so every lower scope's census reads the batches it read.
#
# THE RULING (ceo, 2026-10-29, answering Q3 of row random-codegen-step-11-the-code-road-ceo-1999, DESIGN-PLAN random-codegen-scope step 11):
# "yes. util_inf_snobol4_coverage_census.py's SPREAD gains kind=stmt (preset 3, walk random, limit 12) when the scope is 11 or more. Land
# it yourself in harness, with a red-before arm."
#
# THE DEFECT IT CLOSES: the census generated only its SPREAD (kinds match, expr and both), so no kind=stmt line was ever counted, and the
# coverage arm of test_design_random_codegen_scope_steps.sh --step 11 could never read GREEN, whatever the generator emitted.
#
# THE ARMS, on the census module itself (no generator is built: generate's subprocess is replaced by a fake that records the generator's
# words and writes an empty batch): (1) spread(N) for N = 0..10 is SPREAD, unchanged and in its order; (2) spread(11) and spread(12) are
# SPREAD and then exactly one configuration, kind=stmt preset=3 walk=random limit=12, last, so every earlier configuration keeps its index
# and with it its seeds; (3) generate at --scope 11 runs the generator with kind=stmt (and scope=11), and at --scope 10 never does.
# RED before the landing: the module has no spread().
#
# Usage: bash ../harness/scripts/test_gate_inf_census_spread_takes_statements_from_scope_11.sh
set -uo pipefail
GATE_NAME=test_gate_inf_census_spread_takes_statements_from_scope_11
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
command -v python3 >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: python3 is not on PATH"; exit 2; }
[ -f "$HERE/util_inf_snobol4_coverage_census.py" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no util_inf_snobol4_coverage_census.py beside the gate"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
echo "=== the coverage census counts statement lines from scope 11 ==="
python3 - "$HERE" "$T" <<'EOF'
import os, subprocess, sys
here, tmp = sys.argv[1], sys.argv[2]
sys.path.insert(0, here)
import util_inf_snobol4_coverage_census as c
if not hasattr(c, 'spread'):
    print('  FAIL  (1) the census has no spread(scope): its configurations do not depend on the scope, so kind=stmt is never generated')
    sys.exit(1)
for n in range(0, 11):
    if c.spread(n) != c.SPREAD:
        print('  FAIL  (1) spread(%d) is not SPREAD: %r' % (n, c.spread(n)))
        sys.exit(1)
print('  ok    (1) spread(0..10) is SPREAD, its %d configurations unchanged' % len(c.SPREAD))
want = dict(preset='3', kind='stmt', walk='random', limit='12')
for n in (11, 12):
    s = c.spread(n)
    if s[:len(c.SPREAD)] != c.SPREAD or s[len(c.SPREAD):] != [want]:
        print('  FAIL  (2) spread(%d) is not SPREAD then %r: %r' % (n, want, s))
        sys.exit(1)
print('  ok    (2) spread(11) and spread(12) are SPREAD then kind=stmt preset=3 walk=random limit=12, last')
calls = []
def fake_run(argv, **kw):
    calls.append(argv)
    out = [a[4:] for a in argv if a.startswith('out=')][0]
    open(out, 'w').close()
    return subprocess.CompletedProcess(argv, 0, '', '')
c.subprocess.run = fake_run
seen = {}
for scope in (10, 11):
    del calls[:]
    c.generate('gen', tmp, scope, 1, 3)
    seen[scope] = [a for a in calls if 'kind=stmt' in a]
if seen[10]:
    print('  FAIL  (3) generate at --scope 10 ran the generator with kind=stmt: %r' % seen[10][0])
    sys.exit(1)
if len(seen[11]) != 1 or 'scope=11' not in seen[11][0]:
    print('  FAIL  (3) generate at --scope 11 ran the generator with kind=stmt %d times (want 1, with scope=11): %r' % (len(seen[11]), seen[11]))
    sys.exit(1)
print('  ok    (3) generate runs kind=stmt at --scope 11 (%s) and never at --scope 10' % ' '.join(a for a in seen[11][0][1:] if not a.startswith('out=')))
EOF
rc=$?
[ "$rc" = 0 ] || exit 1
echo "PASS [$GATE_NAME]: the census generates the statement walk from scope 11 and reads the batches it read below it"
exit 0
