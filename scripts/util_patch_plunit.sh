#!/usr/bin/env bash
# util_patch_plunit.sh — patch corpus/tests/prolog/plunit.pl:
#
# Fix 1 (determinism cuts): pj_run_list/pj_run_suite/pj_run_tests leave choice
#   points; backtracking re-enters earlier suites when a later suite fails.
#   Fix: ! after pj_run_suite in pj_run_list, after pj_suite_verdict in
#   pj_run_suite, after pj_run_one in pj_run_tests (body position, not head).
#
# Fix 2 (=@= undefined): test_bips/length gen_list uses =@= (structural
#   equivalence up to variable renaming). Not defined → pj_do_true crashes.
#   Fix: add X =@= Y using copy_term + ==.
#
# Fix 3 (pj_run_suite must not fail): wrap pj_run_suite call in pj_run_list
#   with (... -> true ; true) so a failing suite doesn't abort the list walk.
#
# Idempotent — checks for PATCHED:v2 sentinel before applying.
# After patching, commits corpus repo.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORPUS=$S4E/corpus
PLUNIT=$CORPUS/tests/prolog/plunit.pl

[ -f "$PLUNIT" ] || { echo "ERROR: $PLUNIT not found"; exit 1; }

if grep -q 'PATCHED:v3' "$PLUNIT"; then
    echo "SKIP: plunit.pl already patched (v3)"
    exit 0
fi

echo "Patching $PLUNIT ..."

python3 - "$PLUNIT" << 'PYEOF'
import sys, re

path = sys.argv[1]
src = open(path).read()

# Remove old patch sentinels (replacing v2 with v3)
src = re.sub(r'^/\* PATCHED:v\d+ \*/\n', '', src)
src = src.replace('/* PATCHED:determinism-cuts */\n', '')

# v2 baseline: pj_run_list safe walk (idempotent)
src = src.replace(
    'pj_run_list([H|T]) :- pj_run_suite(H), !, pj_run_list(T).',
    'pj_run_list([H|T]) :- ( pj_run_suite(H) -> true ; true ), !, pj_run_list(T).'
)
src = src.replace(
    'pj_run_list([H|T]) :- pj_run_suite(H), pj_run_list(T).',
    'pj_run_list([H|T]) :- ( pj_run_suite(H) -> true ; true ), !, pj_run_list(T).'
)

# v2 baseline: pj_run_suite — cut after verdict
src = src.replace(
    '    pj_suite_verdict(Suite, SF).',
    '    pj_suite_verdict(Suite, SF), !.'
)

# v3: wrap pj_run_one in once/1.
# Hypothesis (now testable since once/1 is implemented):
#   trailing ! in pj_run_tests recursion may cut the enclosing pj_run_suite
#   continuation, so verdict line never prints. once/1 scopes determinism
#   to pj_run_one only.
src = src.replace(
    'pj_run_tests(Suite, [t(N,O,G)|Rest]) :-\n    pj_run_one(Suite,N,O,G), !, pj_run_tests(Suite,Rest).',
    'pj_run_tests(Suite, [t(N,O,G)|Rest]) :-\n    once(pj_run_one(Suite,N,O,G)), pj_run_tests(Suite,Rest).'
)
src = src.replace(
    'pj_run_tests(Suite, [t(N,O,G)|Rest]) :-\n    pj_run_one(Suite,N,O,G), pj_run_tests(Suite,Rest).',
    'pj_run_tests(Suite, [t(N,O,G)|Rest]) :-\n    once(pj_run_one(Suite,N,O,G)), pj_run_tests(Suite,Rest).'
)

# v3: defense in depth — wrap pj_run_tests call inside pj_run_suite with
# (Body -> true ; true) so any internal failure cannot prevent verdict print.
src = src.replace(
    '    pj_run_tests(Suite, Tests),\n    nb_getval(pj_sf,SF),',
    '    ( pj_run_tests(Suite, Tests) -> true ; true ),\n    nb_getval(pj_sf,SF),'
)

# Ensure =@= is defined (idempotent)
if '=@=' not in src:
    stdlib_anchor = 'pj_insert(X,[H|T],[H|R]) :- pj_insert(X,T,R).'
    src = src.replace(
        stdlib_anchor,
        stdlib_anchor + '\nX =@= Y :- copy_term(X, X1), copy_term(Y, Y1), numbervars(X1,0,N), numbervars(Y1,0,N), X1 == Y1.'
    )

# Sentinel v3
src = '/* PATCHED:v3 */\n' + src

open(path, 'w').write(src)
print("OK")
PYEOF

echo "Committing corpus ..."
cd "$CORPUS"
git config user.name "LCherryholmes"
git config user.email "lcherryh@yahoo.com"
git add prolog/plunit.pl
git commit -m "PL-12: plunit.pl v3 — once/1 around pj_run_one + verdict guard"
echo "DONE"
