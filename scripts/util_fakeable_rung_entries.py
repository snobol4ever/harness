#!/usr/bin/env python3
"""util_fakeable_rung_entries.py -- A RUNG ENTRY A DO-NOTHING ENGINE PASSES (Lon 2026-10-21 16:5x CDT, in-chat to the coo, verbatim: "I suspect
you know not what you are doing and are measuring failure not success." · "You better fix your flawed measurement system for the test suites.";
the coo's COO-388 census; ceo CEO-1868).
An entry is FAKEABLE when its ref is empty and its declared exit code is 0: an engine that compiles, prints nothing and exits 0 passes it, so its
PASS proves only compile-and-terminate. The cure is an authoring landing (the entry OUTPUTs what it computed and its ref is re-cut from the oracle);
until then it leaves the denominator by Lon's ruling. Reads each master through corpus_suite_harness's own readers (the one authority), names in
tests/<lang>/EXCLUDED.tsv already out of the denominator are not counted.
    util_fakeable_rung_entries.py [--corpus DIR] [--lang L]... [--list]
Board line per language and in total: FAKEABLE_BOARD lang=<l>|total fakeable=<n> entries=<e>
rc 0 none · rc 1 a fakeable entry remains · rc 2 could not measure (no master, or the reader refused)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import corpus_suite_harness as csh
LANGS = ('snobol4', 'icon', 'prolog', 'raku', 'pascal', 'snocone', 'rebus')
EXT = {'snobol4': '.sno'}
args = sys.argv[1:]
corpus = os.path.join(HERE, '..', '..', 'corpus')
langs, listing = [], False
while args:
    a = args.pop(0)
    if a == '--corpus' and args:
        corpus = args.pop(0)
    elif a == '--lang' and args:
        langs.append(args.pop(0))
    elif a == '--list':
        listing = True
    else:
        print('usage: util_fakeable_rung_entries.py [--corpus DIR] [--lang L]... [--list]', file=sys.stderr); sys.exit(2)
langs = langs or list(LANGS)
tot_f = tot_e = 0
for lang in langs:
    d = os.path.join(corpus, 'tests', lang)
    lc = csh.LANG_CONFIGS.get(lang)
    src = os.path.join(d, 'ALL' + (lc['ext'] if lc else EXT.get(lang, '')))
    ref = os.path.join(d, 'ALL.ref')
    if not (os.path.isfile(src) and os.path.isfile(ref)):
        print('REFUSE(2): no master at %s' % src); sys.exit(2)
    w = os.path.join(d, 'ALL.wantrc')
    w = w if os.path.isfile(w) else None
    try:
        es = (csh.read_block_suite(src, ref, csh.banner_re_for(lc['comment_open'], lc['comment_close']), w_path=w) if lc
              else csh.read_suite(src, ref, w_path=w))
    except Exception as ex:
        print('REFUSE(2): %s master did not read: %s' % (lang, ex)); sys.exit(2)
    out = set()
    x = os.path.join(d, 'EXCLUDED.tsv')
    if os.path.isfile(x):
        out = {l.split('\t', 1)[0] for l in open(x, encoding='utf-8') if l.strip() and not l.startswith('#')}
    fake = []
    for e in es:
        r = e.ref if isinstance(e.ref, str) else ''.join(e.ref)
        if not r.strip() and e.want_rc == 0 and e.name not in out:
            fake.append(e.name)
    print('FAKEABLE_BOARD lang=%s fakeable=%d entries=%d' % (lang, len(fake), len(es)))
    if listing and fake:
        print('  ' + ' '.join(fake))
    tot_f += len(fake); tot_e += len(es)
print('FAKEABLE_BOARD total fakeable=%d entries=%d' % (tot_f, tot_e))
sys.exit(1 if tot_f else 0)
