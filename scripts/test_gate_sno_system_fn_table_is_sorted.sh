#!/usr/bin/env bash
# test_gate_sno_system_fn_table_is_sorted.sh -- sn4_is_system_fn (src/runtime/snobol4_system_fns.h) is a BINARY SEARCH over
# g_sn4_system_fns[] since the ceo's 2026-09-24 speed-campaign landing (CEO-1247 notebook section 3 item 1): the linear scan
# it replaced ran 77 strcmps on EVERY by-name SNOBOL4 call (treebank x256: 1.15 G of 4.93 G Ir in the scan alone). A binary
# search is only correct over a strcmp-SORTED, DUPLICATE-FREE table, and C cannot assert that at compile time, so this gate
# pins it: the table is parsed out of the header and checked in strcmp (byte) order. No build, ~0.1 s.
# EXIT 0 sorted and unique; 1 a violation (named); 2 REFUSED (the header or the table cannot be found/parsed).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
H="$ROOT/src/runtime/snobol4_system_fns.h"
[ -r "$H" ] || { echo "REFUSED(2): $H not readable"; exit 2; }
python3 - "$H" <<'PY'
import re, sys
src = open(sys.argv[1], encoding='utf-8', errors='replace').read()
if 'g_sn4_system_fns[] = {' not in src or 'int lo = 0, hi = (int)SN4_SYSTEM_FN_COUNT - 1' not in src:
    print("REFUSED(2): the table or the binary search is not where this gate expects it (snobol4_system_fns.h changed shape)"); sys.exit(2)
rc = 0
for tab, fn, floor in (('g_sn4_system_fns', 'sn4_is_system_fn', 50), ('g_sn4_leaf_fns', 'sn4_is_leaf_fn', 40)):
    if tab + '[] = {' not in src:
        print("REFUSED(2): the table %s is not where this gate expects it" % tab); sys.exit(2)
    body = src.split(tab + '[] = {', 1)[1].split('};', 1)[0]
    names = re.findall(r'"([^"\\]*)"', body)
    if len(names) < floor:
        print("REFUSED(2): parsed only %d names from %s; the parse is wrong, not the table" % (len(names), tab)); sys.exit(2)
    bad = [(a, b) for a, b in zip(names, names[1:]) if a.encode() >= b.encode()]
    print("%s: %d names, strcmp-sorted=%s, duplicates=%d" % (tab, len(names), not bad, len(names) - len(set(names))))
    if bad:
        for a, b in bad[:5]: print("  OUT OF ORDER: %r before %r" % (a, b))
        print("GATE FAILED: %s is a binary search and would miss names in an unsorted table -- sort the table (byte order), do not revert the search" % fn); rc = 1
sysfns = set(re.findall(r'"([^"\\]*)"', src.split('g_sn4_system_fns[] = {', 1)[1].split('};', 1)[0]))
leafs = re.findall(r'"([^"\\]*)"', src.split('g_sn4_leaf_fns[] = {', 1)[1].split('};', 1)[0])
stray = [n for n in leafs if n not in sysfns and not n.startswith('SNO$')]
if stray:
    print("GATE FAILED: leaf names that are neither system functions nor SNO$ runtime helpers: %s" % stray); rc = 1
if rc: sys.exit(1)
print("GATE OK")
PY
