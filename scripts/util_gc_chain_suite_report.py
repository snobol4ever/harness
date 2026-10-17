#!/usr/bin/env python3
# util_gc_chain_suite_report.py -- aggregate the SCRIP_GC_CHAIN_LOG file a suite pass appends to (hq_collector 2026-10-11, ARCH-GC section 13, the STEP B population reading).
#   run any suite with SCRIP_GC_CHAIN_CHECK=3 SCRIP_GC_CHAIN_LOG=/path/chain.log in the environment (the harness passes it to scrip and to the mode-4 binaries); every program that exits normally appends one
#   "CMD <argv> | [CHAIN-WALK] SUMMARY ..." line; this script prints the unclean programs first (whole < runs, or any missing, mapdiff, short, extra-*-ptrgc, bad-link, nosite, frameless, no-link,
#   cycle, unknown-depth, left-segment, coroutine-start on a non-root stop) with the counts, then the totals. A program that crashed writes no line: the harness verdict names it.
#   usage: util_gc_chain_suite_report.py LOGFILE [--all]      rc 0 = every logged program clean, 1 = some unclean, 2 = no log
import re, sys
def num(s, k):
    m = re.search(r'\b' + re.escape(k) + r'=(\d+)', s)
    return int(m.group(1)) if m else 0
def main():
    if len(sys.argv) < 2: print("usage: util_gc_chain_suite_report.py LOGFILE [--all]"); return 2
    try: lines = [l.rstrip('\n') for l in open(sys.argv[1], errors='replace') if l.startswith('CMD ')]
    except OSError as e: print("REFUSE(2): " + str(e)); return 2
    if not lines: print("REFUSE(2): no CMD lines in " + sys.argv[1]); return 2
    keys = ['missing', 'mapdiff', 'short', 'extra-blob-ptrgc', 'extra-gen-ptrgc', 'extra-root-ptrgc', 'extra-plain-ptrgc', 'bad-link', 'nosite', 'frameless', 'unknown-depth', 'cycle', 'no-link', 'no-rise']
    bad = []; tot = {k: 0 for k in keys + ['runs', 'whole', 'offchain-swept', 'ghost']}
    for l in lines:
        cmd, _, summ = l[4:].partition(' | ')
        d = {k: num(summ, k) for k in keys + ['runs', 'whole', 'offchain-swept', 'ghost']}
        for k in d: tot[k] += d[k]
        if d['whole'] != d['runs'] or any(d[k] for k in keys):
            bad.append((cmd, d))
    for cmd, d in bad:
        print("UNCLEAN %-60s runs=%d whole=%d %s" % (cmd[:60], d['runs'], d['whole'], ' '.join('%s=%d' % (k, d[k]) for k in keys if d[k])))
    if '--all' in sys.argv:
        for l in lines: print(l[:200])
    print("PROGRAMS %d, UNCLEAN %d; collections whole %d of %d; off-chain frames swept %d (dead per the poison plant, not an unclean count); marker-scan frames that were a dead sibling's %d (the chain is right there, STEP B retires the marker)" % (len(lines), len(bad), tot['whole'], tot['runs'], tot['offchain-swept'], tot['ghost']))
    print("TOTAL " + ' '.join('%s=%d' % (k, tot[k]) for k in keys if tot[k]))
    return 1 if bad else 0
sys.exit(main())
