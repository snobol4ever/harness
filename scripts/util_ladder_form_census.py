#!/usr/bin/env python3
"""util_ladder_form_census.py -- DECLARED FORMS minus BUILT ORIGINS, per language, per rung.

WHY THIS EXISTS (hq_T 2026-09-13, on hq_I's report from inside lib_ladder.sh):
  lib_ladder.sh carries the law that A RUNG DECLARED IN LADDER.tsv AND NOT BUILT IS RED, NOT ABSENT,
  and enforces it AT RUNG GRANULARITY ONLY -- a rung with at least one witness satisfies the check.
  Nothing compares the FORMS column against the origins that actually exist, so snocone rung23
  (six forms declared, four built) grades 8/8 and prints the success shape over two gaps. That is the
  runner's own missing-denominator defect one level down, with FORMS substituted for RUNG.

  hq_I asked the right question before proposing a gate: HOW MANY declared-but-unbuilt forms are there
  across the seven? Turning a refusal on without knowing that is not a gate, it is an outage. This tool
  is the census that answers it, and it is deliberately a REPORT, not a gate -- see THE RULING below.

⛔⭐ THE FIRST CENSUS OF THIS WAS WRONG AND THE REASON IS THE REUSABLE PART. Counting the
  WITNESS_ORIGIN column and diffing it against FORMS reported 218 unbuilt forms for icon and 249 for
  snobol4 -- both false, and false in the direction that manufactures a crisis. THE COLUMN CARRIES
  THREE DIFFERENT CONVENTIONS, and only one of them is machine-readable:
    NAMES  snocone, prolog, raku, pascal -- '|'-separated literal origins, 1:1 with FORMS
    GLOB   icon                          -- a human summary, e.g. 'ladder__rung01_paper_* (8)'
    DASH   rebus, snobol4                -- '-', unpopulated; forms map to origins BY NAME only
  A census keyed on that column answers "is this column populated in the style I assumed", never
  "is the form built". So this tool derives BUILT from ALL.csv -- the rungs is the only authority on
  what exists -- and matches each declared form by name against the rung's own origins. The column is
  then reported as METADATA (which convention it uses), never as evidence.
"""
import argparse, csv, os, re, sys, glob

def load_rungs_origins(lang, root):
    p = os.path.join(root, 'corpus', 'tests', lang, 'ALL.csv')
    if not os.path.exists(p): return None
    out = []
    with open(p, newline='') as fh:
        for i, r in enumerate(csv.reader(fh)):
            if i == 0 or len(r) < 3: continue
            if r[2].startswith('ladder__'): out.append(r[2])
    return out

def rung_of(origin):
    m = re.match(r'^ladder__rung0*(\d+)_', origin)
    return int(m.group(1)) if m else None

def convention(vals):
    """What does the WITNESS_ORIGIN column actually hold? -- reported, never trusted as evidence."""
    seen = [v.strip() for v in vals if v.strip()]
    if not seen or all(v == '-' for v in seen): return 'DASH'
    if any('*' in v or re.search(r'\(\d+\)\s*$', v) for v in seen): return 'GLOB'
    return 'NAMES'

def census_lang(lang, root):
    tsv = os.path.join(root, 'corpus', 'tests', lang, 'config', 'LADDER.tsv')
    if not os.path.exists(tsv): return None
    origins = load_rungs_origins(lang, root)
    if origins is None: return {'lang': lang, 'refuse': 'no ALL.csv -- cannot tell built from unbuilt'}
    by_rung = {}
    for o in origins: by_rung.setdefault(rung_of(o), []).append(o)
    hdr, rows, witcol = None, [], []
    for line in open(tsv):
        line = line.rstrip('\n')
        if not line or line.startswith('#'): continue
        cells = line.split('\t')
        if hdr is None: hdr = cells; continue
        d = dict(zip(hdr, cells))
        m = re.match(r'^rung0*(\d+)$', (d.get('RUNG') or '').strip())
        if not m: continue
        rn = int(m.group(1))
        forms = [f.strip() for f in (d.get('FORMS') or '').split('|') if f.strip()]
        witcol.append(d.get('WITNESS_ORIGIN') or '')
        built = by_rung.get(rn, [])
        matched, unmatched = [], []
        for f in forms:
            hit = [o for o in built if o.endswith('_' + f) or o == 'ladder__rung%02d_%s' % (rn, f) or ('_' + f + '_') in o]
            (matched if hit else unmatched).append(f)
        rows.append({'rung': rn, 'forms': forms, 'built': built, 'matched': matched,
                     'unmatched': unmatched, 'status': (d.get('STATUS') or '').strip()})
    return {'lang': lang, 'rows': rows, 'convention': convention(witcol)}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default=os.environ.get('S4E_HOME') or
                    os.path.dirname(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP")))
    ap.add_argument('--lang', help='one language; default every LADDER.tsv found')
    ap.add_argument('--detail', action='store_true', help='name every unbuilt form')
    a = ap.parse_args()
    langs = [a.lang] if a.lang else sorted(
        p.split('/')[-3] for p in glob.glob(os.path.join(a.root, 'corpus/tests/*/config/LADDER.tsv')))
    if not langs:
        print('REFUSED(2): no corpus/tests/*/config/LADDER.tsv under %s -- nothing to census' % a.root); return 2
    print('%-9s %-6s %6s %6s %8s %8s %8s   %s' % ('lang', 'wit_col', 'rungs', 'forms', 'built', 'AHEAD', 'PARTIAL', 'witnessed rungs with an unbuilt form'))
    tot_f = tot_u = tot_s = 0
    refused = []
    detail = []
    for lang in langs:
        c = census_lang(lang, a.root)
        if c is None: continue
        if 'refuse' in c: print('%-9s REFUSED: %s' % (lang, c['refuse'])); refused.append(lang); continue
        nf = sum(len(r['forms']) for r in c['rows'])
        nu = sum(len(r['unmatched']) for r in c['rows'])
        # ⛔⭐ THE SPLIT IS THE ANSWER, AND A SINGLE TOTAL HIDES IT. A rung with STATUS=PENDING and ZERO built
        # origins is the ladder DECLARED AHEAD -- a roadmap, which is what a construct ladder is supposed to
        # carry -- and gating on it would red every language whose FORMS column looks past the current rung.
        # A rung that has WITNESSES AND STILL DECLARES UNBUILT FORMS is the actual defect hq_I reported: it
        # grades its witnesses, prints the success shape, and says nothing about the forms it is missing.
        # Those are the two numbers a gate decision turns on, so the census prints them apart.
        stand = sum(len(r['unmatched']) for r in c['rows'] if r['built'])
        ahead = nu - stand
        gap_rungs = [r for r in c['rows'] if r['unmatched'] and r['built']]
        tot_f += nf; tot_u += nu; tot_s += stand
        print('%-9s %-6s %6d %6d %8d %8d %8d   %s' % (lang, c['convention'], len(c['rows']), nf, nf - nu, ahead, stand,
              ' '.join('r%d(%d,%s)' % (r['rung'], len(r['unmatched']), r['status'] or '?') for r in gap_rungs) or '--'))
        for r in c['rows']:
            if r['unmatched']:
                detail.append('  %-9s rung%-3d %-9s STATUS=%-14s unbuilt: %s' % (
                    lang, r['rung'], 'PARTIAL' if r['built'] else 'declared-ahead', r['status'] or '(none)', ' '.join(r['unmatched'])))
    print('\nTOTAL declared forms=%d built=%d UNBUILT=%d -- of which %d are DECLARED AHEAD (rung has no witness at all: a roadmap)'
          % (tot_f, tot_f - tot_u, tot_u, tot_u - tot_s))
    print('⛔ %d unbuilt form(s) sit in rungs THAT DO HAVE WITNESSES -- these are the rungs that grade green over a gap,'
          % tot_s)
    print('   and they are the only population a form-granularity refusal could act on without redding a roadmap.')
    # ⛔ the two counts here are DIFFERENT POPULATIONS and happened to both read 17 on the tree this was
    # written against -- rungs carrying a gap, and forms sitting in a witnessed rung. Label both, always.
    # ⛔⭐⭐ A CENSUS THAT COULD NOT MEASURE REFUSES rc=2 -- IT NEVER PRINTS A CLEAN ZERO (hq_T 2026-09-13,
    # caught in this tool by its own author while testing the refusal path, and it is the SAME DEFECT hq_I
    # reported one level up: a missing denominator wearing the success shape). With every language refusing,
    # this printed "UNBUILT=0 ... 0 unbuilt form(s)" and exited 0 -- so a caller scripting on the exit code
    # read NO DEBT where the truth was COULD NOT TELL. The per-language REFUSED lines were printed and were
    # not enough: a summary line and an exit code are what anything downstream actually reads.
    if refused:
        print('\n⛔ REFUSED(2): %d of %d language(s) could not be measured and are NOT in the totals above: %s'
              % (len(refused), len(langs), ' '.join(refused)))
        print('   A form this census cannot see is not a form it proved absent. The numbers above speak only')
        print('   for the %d language(s) it could read.' % (len(langs) - len(refused)))
    if a.detail and detail: print('\n'.join(detail))
    elif detail: print('(%d LADDER.tsv row(s) carry at least one unbuilt form -- a different count from the %d form(s) above; re-run with --detail to name them)'
                       % (len(detail), tot_s))
    # ⛔⭐ THE RULING, so nobody reads this census as a gate-in-waiting: a form matched here is matched BY NAME,
    # and a name match is weaker evidence than a graded witness. This tool can prove a form is NOT built (no
    # origin bears its name); it cannot prove one IS -- an origin could bear the name and grade nothing. So it
    # reports a FLOOR on the debt, never a ceiling, and it is that asymmetry, not squeamishness, that keeps it
    # out of lib_ladder.sh's verdict path.
    return 2 if refused else 0

sys.exit(main())
