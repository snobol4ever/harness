#!/usr/bin/env python3
# classify.py -- THE CENSUS OF DESIGN-PLAN gates-zero (the cto, 2026-11-12, CTO-637; Lon: "take those almost 2000 scripts to ZERO").
# One row per harness/scripts/test_gate_*.sh: name, class, language, lines, and who still names it:
#   class source   reads SCRIP's text only (greps a file, a spelling, a count per file): deleted at step 1
#   class program  runs scrip or a runner on a program: its programs become entries of their language's container (graded by the cycle), then deleted
#   class fleet    tests the bus, the box or the harness itself (a scratch postoffice, s4e_msg.sh, the slots): the cio's to retire
#   live           the DONE-WHEN or PREMISE-WHEN of a live row names it (kept until that row closes or is recut)
# Writes GATES.tsv beside this file and prints the counts.
import collections, glob, os, re, sys
H = os.path.dirname(os.path.abspath(__file__))
S = os.path.normpath(os.path.join(H, '..', '..', 'scripts'))
sys.path.insert(0, S)
import harness_paths as HP
PO = '/home/resources/postoffice'
RUN = re.compile(r'\./scrip\b|\$\{?SCRIP\}?\b|\$\{?ROOT\}?/scrip\b|/scrip["\' ]|\bscrip --|corpus_suite_harness\.py"? (run|grade)|monitor_run\.sh|util_run_slot\.sh|lib_one_runner\.sh|'
                 r'test_smoke_|test_feature_reps|lib_ladder\.sh|run_prog|run_one\b|\$SC/scrip|scrip_bin|libscrip_rt\.so')
FLEET = re.compile(r's4e_msg\.sh|S4E_POST\b|postoffice|lib_slots\.sh|util_batch\.sh|s4e_land\.sh|mode_flip|lib_wake|util_mem_scope|QUEUE\.tsv|s4e_worktree|cgroup')
LANG = [('icon', r'^test_gate_(icn|icon|unicon|uni)_'), ('prolog', r'^test_gate_(pl|prolog|swi|xsb|gnu|clp|chr)_'), ('pascal', r'^test_gate_(pas|pascal|fpc)_'),
        ('raku', r'^test_gate_(raku|rk)_'), ('snobol4', r'^test_gate_(sno|snobol4|snocone|rebus|spitbol)_')]
live = set()
try:
    rows = [l.split('\t')[1] for l in open(os.path.join(PO, 'QUEUE.tsv')) if l.strip() and not l.startswith('#') and len(l.split('\t')) > 1]
except OSError:
    rows = []
for t in rows:
    p = os.path.join(PO, 'tasks', t + '.task.md')
    if os.path.exists(p):
        for ln in open(p, errors='replace'):
            if ln.startswith(('DONE-WHEN', 'PREMISE-WHEN')):
                live.update(re.findall(r'test_gate_\w+', ln))
mk = open(os.path.join(str(HP.scrip()), 'Makefile'), errors='replace').read()
out, cnt = [], collections.Counter()
for f in sorted(glob.glob(os.path.join(S, 'test_gate_*.sh'))):
    n = os.path.basename(f)[:-3]
    t = open(f, errors='replace').read()
    code = '\n'.join(l for l in t.split('\n') if not l.lstrip().startswith('#'))
    cls = 'fleet' if FLEET.search(code) and not RUN.search(code) else ('program' if RUN.search(code) else 'source')
    lang = next((k for k, rx in LANG if re.match(rx, n)), 'shared')
    out.append((n, cls, lang, str(t.count('\n')), 'live' if n in live else '-', 'make' if n + '.sh' in mk else '-'))
    cnt[cls] += 1
    if n in live:
        cnt['live'] += 1
with open(os.path.join(H, 'GATES.tsv'), 'w') as o:
    o.write('# GATES.tsv -- written by classify.py (DESIGN-PLAN gates-zero, CTO-637): name class language lines live make\n')
    for r in out:
        o.write('\t'.join(r) + '\n')
print('gates=%d %s' % (len(out), ' '.join('%s=%d' % kv for kv in sorted(cnt.items()))))
by = collections.Counter((r[1], r[2]) for r in out)
for k in sorted(by):
    print('  %-8s %-8s %d' % (k[0], k[1], by[k]))
