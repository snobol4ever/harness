#!/usr/bin/env python3
"""util_swi_red_census.py -- THE SWI SUITE'S REDS, CLASSED BY TEST FILE AND FIRST BUILTIN, EACH CLASS ROWED OR EXCLUDED
(ceo CEO-1562, on Lon's 2026-10-08 question whether the fleet has a proper incremental plan to 100%; row
instruments-the-swi-suites-reds-are-classed-by-test-file-and-every-class-has-a-row-or-an-excluded-line-ceo-1562).

It runs nothing. It READS: the oracle's enumeration (the .ref beside every plunit file of swi_tests, cut from swipl by
util_swi_cut_refs.sh: PASS|FAIL cases are the graded population, BLOCKED/EMPTY/UNGRADABLE are the oracle's own and leave it),
the progress database's LAST reading of every case in every mode (/home/resources/progress/results.tsv, suite `swi`; the
rows test_prolog_swi_suite.sh appends, whole board or round-robin part), the package's EXCLUDED_CASES.tsv, and the live
rows of the postoffice QUEUE (topic plus the GOAL, DONE-WHEN, LINKS and ## NEXT of the row's task file).

A CASE IS RED when any mode's last reading is not PASS (the suite's AND-per-case verdict). A case in EXCLUDED_CASES.tsv is
never red: it is counted EXCLUDED (the reading predates the exclusion). A graded case with no reading is UNREAD, named in the
header, never a pass and never a red.

A CLASS is (test file, family): the family is the first builtin the test's body names (its first goal -- through once/ignore/
call/not/\\+/catch -- as its predicate, its infix operator, or its bare atom), read from the k-th test/2 head of that name in
the label's unit. A family with fewer than MIN_CLASS reds in its file folds into that file's `*` class, so every red belongs to
exactly one class. Rows are minted per class (a predicate family, a library module, a flag), never per test.

A CLASS IS ROWED when a live QUEUE row (FREE, CLAIMED, ASSIGNED, BLOCKED-ON, GRANT-NEEDED, PARKED-LON-HOLD, PARKED-UMBRELLA,
PARKED-AWAITING) COVERS it: the row's topic carries the file's slug (core-test-read: a whole-file row), or the row's DONE-WHEN runs
the file (names core/test_read or core/test_read.pl) -- every class of that file, unless the DONE-WHEN names families with
`util_swi_red_census.py --witness FILE FAMILY`, which then covers exactly those. Prose in a GOAL or a ledger covers nothing: a row is
what it RUNS. A class is EXCLUDED when every red it holds is in EXCLUDED_CASES.tsv.

    util_swi_red_census.py --witness FILE FAMILY|'*'   THE ROW'S DONE-WHEN: one-file run of the SWI runner (no board, no row written), rc 0
                 when the class has no red in either mode, rc 1 naming the reds still red, rc 2 when the run could not be read. FAMILY is
                 the census's own name for the class; `*` is every case of the file.

    rc 0  GREEN  every class of MIN_CLASS or more reds is rowed or excluded
    rc 1  RED    some class of MIN_CLASS or more reds has neither (named, with its count)
    rc 2  could not read a grading (no refs, no progress database, no swi readings, a malformed EXCLUDED_CASES.tsv)

    util_swi_red_census.py [--min N] [--all] [--selftest]
      --min N    the class size that must be rowed or excluded (default 10)
      --all      print every class, not only those of --min or more reds
      --selftest scratch package, database and queue under mktemp: an unrowed class reads rc 1 naming it, rows it -> rc 0, an
                 EXCLUDED_CASES.tsv line -> rc 0, a missing database -> rc 2
env: S4E_PROGRESS_DB, S4E_POSTOFFICE, S4E_SWI_TESTS redirect the three inputs, S4E_SWI_RUNNER the runner --witness calls (the selftest and gates use them).
"""
import csv, os, re, sys, collections, tempfile, shutil, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
S4E = os.environ.get('S4E_HOME') or os.path.normpath(os.path.join(HERE, '..', '..'))
DB = os.environ.get('S4E_PROGRESS_DB', '/home/resources/progress/results.tsv')
PO = os.environ.get('S4E_POSTOFFICE', '/home/resources/postoffice')
SWIT = os.environ.get('S4E_SWI_TESTS', os.path.join(S4E, 'corpus', 'packages', 'prolog', 'swi_tests'))
SUITE = 'swi'
LIVE = ('FREE', 'CLAIMED', 'ASSIGNED', 'BLOCKED-ON', 'GRANT-NEEDED', 'PARKED-LON-HOLD', 'PARKED-UMBRELLA', 'PARKED-AWAITING')
EXCL_CLASSES = ('SCRIP_EXCEEDS_ORACLE', 'NO_ORACLE_ANSWER', 'THREADS_EXCLUDED_BY_LON')
WRAPPERS = ('once', 'ignore', 'call', 'not', 'catch')
OPRX = re.compile(r'=\\=|=:=|=@=|\\=@=|=\.\.|\\==|==|=<|>=|@=<|@>=|@<|@>|\\=|=|<|>|\bis\b|\bas\b')
SYMCH = set('#$&*+-./:<=>?@^~\\')


class Refuse(Exception):
    pass


def refuse(msg):
    raise Refuse(msg)


def clean_clauses(text):
    """Yield (start_line, cleaned clause text, neck index or -1) for every clause: comments gone, quotes kept."""
    i, n = 0, len(text)
    out = []
    while i < n:
        while i < n and text[i] in ' \t\r\n':
            i += 1
        if i >= n:
            break
        if text[i] == '%':
            while i < n and text[i] != '\n':
                i += 1
            continue
        if text.startswith('/*', i):
            j = text.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        start, line0 = i, text.count('\n', 0, i) + 1
        buf, depth, neck = [], 0, -1
        while i < n:
            c = text[i]
            if c == '%':
                while i < n and text[i] != '\n':
                    i += 1
                continue
            if text.startswith('/*', i):
                j = text.find('*/', i + 2)
                i = n if j < 0 else j + 2
                continue
            if c == '0' and text.startswith("0'", i) and i + 2 < n and (i == start or not (text[i - 1].isalnum() or text[i - 1] == '_')):
                k = i + 3 if text[i + 2] != '\\' else i + 4
                buf.append(text[i:k]); i = k
                continue
            if c in '\'"`':
                j = i + 1
                while j < n:
                    if text[j] == '\\':
                        j += 2
                        continue
                    if text[j] == c:
                        if j + 1 < n and text[j + 1] == c:
                            j += 2
                            continue
                        break
                    j += 1
                buf.append(text[i:j + 1]); i = j + 1
                continue
            if c in '([{':
                depth += 1
            elif c in ')]}':
                depth -= 1
            elif c == ':' and depth == 0 and text.startswith(':-', i) and neck < 0 and (i == 0 or text[i - 1] not in SYMCH):
                neck = len(''.join(buf))
            elif c == '.' and depth <= 0 and (i + 1 >= n or text[i + 1] in ' \t\r\n%') and (i == 0 or text[i - 1] not in SYMCH):
                i += 1
                break
            buf.append(c); i += 1
        s = ''.join(buf)
        out.append((line0, s, neck))
    return out


def split_top(s, seps):
    """Split s at depth-0 occurrences of any separator string in seps (longest first); return the pieces."""
    pieces, depth, i, last = [], 0, 0, 0
    seps = sorted(seps, key=len, reverse=True)
    while i < len(s):
        c = s[i]
        if c in '\'"`':
            j = i + 1
            while j < len(s) and s[j] != c:
                j += 2 if s[j] == '\\' else 1
            i = j + 1
            continue
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
        elif depth == 0:
            for sp in seps:
                if s.startswith(sp, i):
                    pieces.append(s[last:i]); i += len(sp); last = i
                    break
            else:
                i += 1
                continue
            continue
        i += 1
    pieces.append(s[last:])
    return pieces


def match_close(s, i):
    """Index of the paren closing the one opened at s[i], or -1."""
    depth = 0
    for j in range(i, len(s)):
        c = s[j]
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
            if depth == 0:
                return j
    return -1


def depth0(g):
    """g with everything inside brackets or quotes blanked, so an operator is found only where it joins the goal's own terms."""
    out, depth, i = [], 0, 0
    while i < len(g):
        c = g[i]
        if c in '\'"`':
            j = i + 1
            while j < len(g) and g[j] != c:
                j += 2 if g[j] == '\\' else 1
            out.append(' ' * (min(j, len(g) - 1) - i + 1)); i = j + 1
            continue
        if c in '([{':
            depth += 1
        out.append(c if depth == 0 else ' ')
        if c in ')]}':
            depth -= 1
        i += 1
    return ''.join(out)


def family_of_goal(g, depth=0):
    g = g.strip()
    while g.startswith('\\+'):
        g = g[2:].strip()
    while g.startswith('(') and match_close(g, 0) == len(g) - 1:
        g = split_top(g[1:-1], (',', ';', '->', '*->'))[0].strip()
    m = re.match(r'(?:[a-z][A-Za-z0-9_]*:)?([a-z][A-Za-z0-9_]*)\s*\(', g)
    if m:
        close = match_close(g, m.end() - 1)
        mo = OPRX.match(g[close + 1:].strip()) if close >= 0 else None
        if mo:
            return mo.group(0)
        name = m.group(1)
        if name in WRAPPERS and depth < 3 and close >= 0:
            return family_of_goal(split_top(g[m.end():close], (',',))[0], depth + 1)
        return name
    mo = OPRX.search(depth0(g))
    if mo:
        return mo.group(0)
    m = re.match(r'^([a-z][A-Za-z0-9_]*)$', g)
    return m.group(1) if m else '(goal)'


def first_family(body):
    goal = split_top(body, (',', ';', '->', '*->'))[0]
    return family_of_goal(goal) if goal.strip() else '(empty)'


def source_families(path):
    """{unit: {test name: [family of its k-th head]}} in source order -- the k-th head of a name is the label's #k."""
    try:
        text = open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return {}
    fam = collections.defaultdict(lambda: collections.defaultdict(list))
    unit = None
    for _, s, neck in clean_clauses(text):
        m = re.match(r':-\s*begin_tests\(\s*([A-Za-z0-9_]+)', s)
        if m:
            unit = m.group(1); continue
        if re.match(r':-\s*end_tests\(', s):
            unit = None; continue
        if unit is None:
            continue
        m = re.match(r"test\(\s*('(?:[^'\\]|\\.)*'|[A-Za-z0-9_]+)", s)
        if not m:
            continue
        name = m.group(1)
        if name.startswith("'"):
            name = name[1:-1].replace("\\'", "'")
        fam[unit][name].append(first_family(s[neck + 2:]) if neck >= 0 else '(options)')
    return fam


def norm_test(t):
    m = re.match(r'^@\(([^,]+),', t)
    return m.group(1) if m else t


def graded_population(swit):
    """[(rel, label, unit, test, k)] for every PASS/FAIL case of every ref under swit; the oracle's enumeration."""
    pop = []
    if not os.path.isdir(swit):
        refuse('no vendored package at %s' % swit)
    for dp, _, fns in sorted(os.walk(swit)):
        for fn in sorted(fns):
            if not fn.endswith('.ref'):
                continue
            ref = os.path.join(dp, fn)
            rel = os.path.relpath(ref[:-4] + '.pl', swit)
            seen = collections.Counter()
            for line in open(ref, encoding='utf-8', errors='replace'):
                parts = line.rstrip('\n').split(' ', 1)
                if len(parts) < 2 or parts[0] not in ('PASS', 'FAIL'):
                    continue
                u, _, t = parts[1].partition(':')
                t = norm_test(t)
                seen[(u, t)] += 1
                pop.append((rel, '%s:%s#%d' % (u, t, seen[(u, t)]), u, t, seen[(u, t)]))
    if not pop:
        refuse('no .ref with a PASS or FAIL case under %s' % swit)
    return pop


def excluded_cases(swit):
    ex = {}
    p = os.path.join(swit, 'EXCLUDED_CASES.tsv')
    if not os.path.exists(p):
        return ex
    for n, l in enumerate(open(p, encoding='utf-8').read().split('\n'), 1):
        if not l.strip() or l.startswith('#'):
            continue
        c = l.split('\t')
        if len(c) < 4 or c[2] not in EXCL_CLASSES or not c[3].strip():
            refuse('%s line %d is not file<TAB>case<TAB>%s<TAB>measurement' % (p, n, '|'.join(EXCL_CLASSES)))
        ex[(c[0], c[1])] = c[2]
    return ex


def is_excluded(ex, rel, label):
    return (rel, label) in ex or (rel, label.rsplit('#', 1)[0]) in ex


def last_readings(db):
    if not os.path.exists(db):
        refuse('no progress database at %s' % db)
    last = {}
    with open(db, encoding='utf-8', newline='') as f:
        rd = csv.reader(f, delimiter='\t')
        hdr = next(rd, None)
        if not hdr or 'program' not in hdr or 'outcome' not in hdr:
            refuse('%s has no header naming program and outcome' % db)
        ix = {h: i for i, h in enumerate(hdr)}
        for r in rd:
            if len(r) <= ix['outcome'] or r[ix['suite']] != SUITE:
                continue
            r = r + [''] * (len(hdr) - len(r))
            last[(r[ix['program']], r[ix['mode']])] = (r[ix['ts_utc']], r[ix['outcome']], r[ix['scrip']])
    if not last:
        refuse('%s holds no row of suite %s' % (db, SUITE))
    return last


def live_rows(po):
    """[(topic, state, DONE-WHEN text, lowercase topic)] for every live row: what a row RUNS is what it covers, not what its prose mentions."""
    q = os.path.join(po, 'QUEUE.tsv')
    if not os.path.exists(q):
        refuse('no queue at %s' % q)
    rows = []
    for l in open(q, encoding='utf-8'):
        if l.startswith('#') or not l.strip():
            continue
        c = l.rstrip('\n').split('\t')
        if len(c) < 4 or not c[3].startswith(LIVE):
            continue
        topic, dw = c[1], ''
        tp = os.path.join(po, 'tasks', topic + '.task.md')
        if os.path.exists(tp):
            for tl in open(tp, encoding='utf-8', errors='replace').read().split('\n'):
                if tl.startswith('DONE-WHEN:'):
                    dw = tl; break
        rows.append((topic, c[3], dw, topic.lower()))
    return rows


def file_slug(rel):
    noext = rel[:-3] if rel.endswith('.pl') else rel
    return noext, noext.replace('/', '-').replace('_', '-').lower()


def row_for(cls_file, cls_family, rows):
    """The live row that covers class (file, family): its topic carries the file's slug (a whole-file row), or its DONE-WHEN runs the file --
    every class of it, unless the DONE-WHEN names families with `--witness FILE FAMILY`, which then covers exactly those."""
    noext, slug = file_slug(cls_file)
    path = re.compile(r'(?<![\w/])' + re.escape(noext) + r'(?![\w])')
    wit = re.compile(r'--witness\s+' + re.escape(cls_file) + r'\s+(\S+)')
    for topic, state, dw, tl in rows:
        if slug in tl:
            return topic, state
        if not path.search(dw):
            continue
        fams = [x.strip('\'"') for x in wit.findall(dw)]
        if not fams or cls_family in fams:
            return topic, state
    return None


def census(min_class, show_all, out=sys.stdout):
    pop = graded_population(SWIT)
    last = last_readings(DB)
    ex = excluded_cases(SWIT)
    rows = live_rows(PO)
    fams = {rel: source_families(os.path.join(SWIT, rel)) for rel in {p[0] for p in pop}}
    modes = sorted({m for (_, m) in last})
    n_pass = n_unread = n_excl_red = 0
    reds = []
    stamps = []
    for rel, label, u, t, k in pop:
        prog = '%s:%s' % (rel, label)
        outs = {m: last[(prog, m)] for m in modes if (prog, m) in last}
        if not outs:
            n_unread += 1; continue
        stamps.extend(v[0] for v in outs.values())
        if all(v[1] == 'PASS' for v in outs.values()):
            n_pass += 1; continue
        if any(v[1] in ('UNGRADED', 'UNGRADABLE') for v in outs.values()):
            continue
        kinds = {m: v[1] for m, v in outs.items()}
        fl = fams.get(rel, {}).get(u, {}).get(t, [])
        fam = fl[k - 1] if k - 1 < len(fl) else '(generated)'
        reds.append((rel, fam, label, kinds, is_excluded(ex, rel, label), max(v[0] for v in outs.values() if v[1] != 'PASS'), {v[2] for v in outs.values() if v[1] != 'PASS'}))
    if not reds and n_pass == 0:
        refuse('no case of the oracle\'s enumeration has a reading in %s' % DB)
    per_file_fam = collections.Counter((r[0], r[1]) for r in reds if not r[4])
    age = collections.Counter(r[5][:10] for r in reds if not r[4])
    file_total = collections.Counter(r[0] for r in reds if not r[4])
    classes = collections.OrderedDict()
    for rel, fam, label, kinds, exc, stamp, trees in reds:
        key_fam = fam if per_file_fam[(rel, fam)] >= min_class else '*'
        c = classes.setdefault((rel, key_fam), {'n': 0, 'excl': 0, 'kind': collections.Counter(), 'where': collections.Counter(), 'fams': collections.Counter(), 'dates': set(), 'trees': set()})
        if exc:
            c['excl'] += 1; n_excl_red += 1; continue
        c['n'] += 1; c['fams'][fam] += 1; c['dates'].add(stamp[5:10]); c['trees'].update(trees)
        bad = [m for m, o in kinds.items() if o != 'PASS']
        c['where']['both' if len(bad) == len(kinds) else bad[0] + 'only'] += 1
        c['kind'][kinds[bad[0]]] += 1
    lines, unrowed = [], []
    n_rowed = n_excl = 0
    for (rel, fam), c in classes.items():
        if c['n'] == 0:
            n_excl += 1
            lines.append((0, rel, fam, c, 'EXCLUDED(%d)' % c['excl'], True))
            continue
        row = row_for(rel, fam, rows)
        if row:
            n_rowed += 1
            tag = 'ROW %s [%s]' % (row[0], row[1].split(':')[0])
        else:
            tag = 'UNROWED'
            if c['n'] >= min_class:
                unrowed.append((rel, fam, c['n']))
        if c['excl']:
            tag += ' +%d excluded' % c['excl']
        lines.append((c['n'], rel, fam, c, tag, bool(row)))
    lines.sort(key=lambda x: (-x[0], x[1], x[2]))
    total_red = sum(file_total.values())
    p = lambda s='': print(s, file=out)
    p('SWI_RED_CENSUS basis: %d graded cases in the oracle\'s refs, last reading per case and mode from %s (%s .. %s)' % (len(pop), DB, min(stamps)[:10] if stamps else '?', max(stamps)[:10] if stamps else '?'))
    p('  pass %d  red %d (EXCLUDED_CASES.tsv names %d more reds whose reading predates the exclusion)  unread %d' % (n_pass, total_red, n_excl_red, n_unread))
    p('  the reds\' last readings, by day: ' + ' '.join('%s=%d' % kv for kv in sorted(age.items())) + '  (a stale reading is re-measured by --witness, then by the coo\'s next pass: s4e_test_request.sh swi)')
    p('  classes: %d (a family under %d reds folds into its file\'s `*`)  rowed %d  excluded %d  unrowed %d' % (len(classes), min_class, n_rowed, n_excl, len(classes) - n_rowed - n_excl))
    for n, rel, fam, c, tag, rowed in lines:
        if not show_all and 0 < n < min_class:
            continue
        kinds = ' '.join('%s=%d' % kv for kv in sorted(c['kind'].items()))
        where = ' '.join('%s=%d' % kv for kv in sorted(c['where'].items()))
        extra = ''
        if fam == '*' and len(c['fams']) > 1:
            extra = ' families: ' + ' '.join('%s=%d' % kv for kv in c['fams'].most_common(4))
        when = ('%s..%s @%s' % (min(c['dates']), max(c['dates']), ','.join(sorted(t[:7] for t in c['trees'])[:3]))) if c['dates'] else ''
        p('  %4d  %-44s :: %-22s %s | %s | %s | read %s%s' % (n, rel, fam, tag, kinds, where, when, extra))
    bydir = collections.Counter()
    for rel, n in file_total.items():
        bydir[rel.split('/')[0]] += n
    p('  by directory: ' + ' '.join('%s=%d' % kv for kv in bydir.most_common()))
    tail = sum(c['n'] for (rel, fam), c in classes.items() if c['n'] < min_class and not row_for(rel, fam, rows))
    p('  unrowed reds in classes under %d (the tail, not required): %d' % (min_class, tail))
    if unrowed:
        p('RED: %d class(es) of %d or more reds have neither a live QUEUE row nor an EXCLUDED line (%d reds): %s' % (
            len(unrowed), min_class, sum(u[2] for u in unrowed), ' '.join('%s::%s=%d' % u for u in sorted(unrowed, key=lambda u: -u[2])[:12])))
        return 1
    p('GREEN: every class of %d or more reds is rowed or excluded' % min_class)
    return 0


def case_family(fams, rel, label):
    u, _, rest = label.partition(':')
    t, _, k = rest.rpartition('#')
    fl = fams.get(u, {}).get(t, [])
    return fl[int(k) - 1] if k.isdigit() and int(k) - 1 < len(fl) else '(generated)'


def witness(rel, family):
    """Grade one file through the runner's --file mode (writes no progress row and no score row) and read the class's reds off --name-reds."""
    runner = os.environ.get('S4E_SWI_RUNNER') or os.path.join(HERE, 'test_prolog_swi_suite.sh')
    if not os.path.exists(os.path.join(SWIT, rel)):
        refuse('%s is not a file of %s' % (rel, SWIT))
    try:
        r = subprocess.run(['bash', runner, '--file', rel, '--name-reds'], capture_output=True, text=True, timeout=int(os.environ.get('SWI_WITNESS_TIMEOUT', '1800')))
    except subprocess.TimeoutExpired:
        refuse('the runner did not finish %s inside SWI_WITNESS_TIMEOUT' % rel)
    if r.returncode == 2 or 'SWI_BOARD' not in r.stdout:
        refuse('the runner could not grade %s (rc %d): %s' % (rel, r.returncode, (r.stdout + r.stderr).strip().split('\n')[-1][:200]))
    fams = source_families(os.path.join(SWIT, rel))
    rx = re.compile(r'^\s*RED\s+(\S+\.pl):(.+#\d+):(m3|m4):')
    bad = collections.OrderedDict()
    for line in r.stdout.split('\n'):
        m = rx.match(line)
        if m and m.group(1) == rel and (family == '*' or case_family(fams, rel, m.group(2)) == family):
            bad.setdefault(m.group(2), []).append(m.group(3))
    if not bad:
        print('GREEN: %s :: %s has no red case in either mode' % (rel, family))
        return 0
    print('RED: %s :: %s -- %d case(s) still red: %s' % (rel, family, len(bad), '; '.join('%s [%s]' % (k, ','.join(v)) for k, v in list(bad.items())[:6])))
    return 1


def selftest():
    tmp = tempfile.mkdtemp(prefix='swi_red_census_')
    me = os.path.abspath(__file__)
    try:
        sw = os.path.join(tmp, 'swi_tests'); os.makedirs(os.path.join(sw, 'core'))
        po = os.path.join(tmp, 'po'); os.makedirs(os.path.join(po, 'tasks'))
        cases = ['a%d' % i for i in range(12)]
        with open(os.path.join(sw, 'core', 'test_x.pl'), 'w') as f:
            f.write(':- begin_tests(x).\n' + ''.join('test(%s) :- atom_length(abc, _), true.\n' % c for c in cases) + ':- end_tests(x).\n')
        with open(os.path.join(sw, 'core', 'test_x.ref'), 'w') as f:
            f.write(''.join('PASS x:%s\n' % c for c in cases))
        db = os.path.join(tmp, 'results.tsv')
        with open(db, 'w') as f:
            f.write('ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\tfingerprint\tconfig\n')
            for c in cases:
                for m in ('m3', 'm4'):
                    f.write('2026-10-21T00:00:00\ts\tc\tcoo\tpackage\tswi\tprolog\tcore/test_x.pl:x:%s#1\t%s\tFAIL\t0\t\t\tundeclared\n' % (c, m))
        q = os.path.join(po, 'QUEUE.tsv')
        open(q, 'w').write('# rank\ttopic\towner\tstate\n3\tunrelated-row\tcoo\tFREE\n')
        env = dict(os.environ, S4E_PROGRESS_DB=db, S4E_POSTOFFICE=po, S4E_SWI_TESTS=sw)
        def run(label, want, e=None):
            r = subprocess.run([sys.executable, '-I', me], env=e or env, capture_output=True, text=True)
            ok = r.returncode == want
            print('  %-58s rc=%d want %d  %s' % (label, r.returncode, want, 'ok' if ok else 'WRONG'))
            if not ok:
                print(r.stdout[-600:] + r.stderr[-600:])
            return ok
        ok = run('twelve reds in one file, no row -> RED', 1)
        open(q, 'a').write('3\tprolog-swi-core-test-x-every-case\thq_packages\tFREE\n')
        ok &= run('a live row whose topic carries the file slug -> GREEN', 0)
        open(q, 'w').write('# rank\ttopic\towner\tstate\n3\tprolog-swi-core-test-x-every-case\thq_packages\tDONE\n')
        ok &= run('the same row DONE is no row -> RED', 1)
        open(q, 'w').write('# rank\ttopic\towner\tstate\n3\tfamily-row\thq_packages\tFREE\n')
        def task(dw, goal='GOAL: core/test_x.pl is named only in prose\n'):
            open(os.path.join(po, 'tasks', 'family-row.task.md'), 'w').write(goal + 'DONE-WHEN: ' + dw + '\n')
        task('echo nothing')
        ok &= run('a row that only mentions the file in its GOAL covers nothing -> RED', 1)
        task('python3 util_swi_red_census.py --witness core/test_x.pl atom_length')
        ok &= run('a DONE-WHEN witness for the file and the class family -> GREEN', 0)
        task('python3 util_swi_red_census.py --witness core/test_x.pl sub_atom')
        ok &= run('a DONE-WHEN witness for the file but another family -> RED', 1)
        task('for f in core/test_x.pl; do bash runner --file "$f"; done')
        ok &= run('a DONE-WHEN that runs the whole file -> GREEN', 0)
        open(q, 'w').write('# rank\ttopic\towner\tstate\n')
        open(os.path.join(sw, 'EXCLUDED_CASES.tsv'), 'w').write(''.join('core/test_x.pl\tx:%s\tNO_ORACLE_ANSWER\toracle crashes\n' % c for c in cases))
        ok &= run('every red in EXCLUDED_CASES.tsv -> GREEN', 0)
        os.remove(os.path.join(sw, 'EXCLUDED_CASES.tsv'))
        ok &= run('no progress database -> rc 2', 2, dict(env, S4E_PROGRESS_DB=os.path.join(tmp, 'absent.tsv')))
        fake = os.path.join(tmp, 'runner.sh')
        open(fake, 'w').write('#!/bin/bash\necho "SWI_BOARD declared=12"\n[ -f "%s/red" ] && for c in a0 a1; do echo "    RED core/test_x.pl:x:$c#1:m3:oracle PASS / scrip FAIL"; done\nexit 0\n' % tmp)
        wenv = dict(env, S4E_SWI_RUNNER=fake)
        def wit(label, want, fam='atom_length'):
            r = subprocess.run([sys.executable, '-I', me, '--witness', 'core/test_x.pl', fam], env=wenv, capture_output=True, text=True)
            good = r.returncode == want
            print('  %-58s rc=%d want %d  %s' % (label, r.returncode, want, 'ok' if good else 'WRONG'))
            if not good:
                print(r.stdout[-400:] + r.stderr[-400:])
            return good
        open(os.path.join(tmp, 'red'), 'w').write('')
        ok &= wit('--witness with two reds in the class -> RED', 1)
        ok &= wit('--witness for a family holding none of them -> GREEN', 0, 'sub_atom')
        os.remove(os.path.join(tmp, 'red'))
        ok &= wit('--witness once the reds are gone -> GREEN', 0)
        print('selftest', 'PASS' if ok else 'FAIL')
        return 0 if ok else 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main(argv):
    min_class, show_all = 10, False
    args = list(argv)
    while args:
        a = args.pop(0)
        if a == '--selftest':
            return selftest()
        if a == '--witness' and len(args) == 2:
            try:
                return witness(args[0], args[1])
            except Refuse as e:
                print('REFUSED(rc=2) [util_swi_red_census --witness]: %s' % e)
                return 2
        if a == '--all':
            show_all = True
        elif a == '--min' and args and args[0].isdigit() and int(args[0]) > 0:
            min_class = int(args.pop(0))
        else:
            sys.stderr.write(__doc__)
            return 2
    try:
        return census(min_class, show_all)
    except Refuse as e:
        print('REFUSED(rc=2) [util_swi_red_census]: %s' % e)
        return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
