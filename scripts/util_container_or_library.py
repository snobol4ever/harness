#!/usr/bin/env python3
"""util_container_or_library.py -- CONTAINER_OR_LIBRARY SPLIT BY MEASUREMENT, FILE BY FILE (ceo CEO-1272; CEO-700, CEO-1245, CEO-1269).

The UNGRADABLE class CONTAINER_OR_LIBRARY conflated two facts. This instrument measures which one a file is, from the file and
the package around it, never from a row's prose:

  LIBRARY    it defines callable code (Icon procedures, SNOBOL4 DEFINEd functions, Prolog clauses) and has no entry point of its
             own. It is a PROGRAM owed its driver: UNGRADED, class NEEDS_DRIVER, in the denominator as a named non-pass (CEO-1269).
  CONTAINER  it is not a compilation unit on its own. It leaves the shipped population, named in CONTAINERS.tsv with the
             measurement that makes it one -- one of six KINDs:
               INCLUDED_BY <rel>   <rel> splices it: an Icon $include, a SNOBOL4 -INCLUDE, a Prolog/Logtalk include/1, or a
                                   csnobol4 tests.in -L preload names it (resolved from <rel>'s directory, else by a basename
                                   unique in the package)
               OPENED_BY <rel>     <rel> names it outside any load or include directive and it holds facts alone -- a data
                                   file a test opens and reads (a file of rules a test loads at run time is a library)
               LOADED_BY <rel>     <rel>'s load directive names it -- a Prolog consult, ensure_loaded, use_module, load_files or
                                   reexport (include stays INCLUDED_BY): a module of rules a program loads and is graded through,
                                   not a program on its own (ceo CEO-1621, 2026-10-10; the harness stages it, coo cd52d401e)
               SCAFFOLDING         every term is a directive and at least one loads or includes something: the suite's own loader; or a Prolog
                                   file of ONE clause whose body is bare '$use_<module>' goals, each a bare fact in a sibling file (a link list)
               NO_DEFINITION       it defines nothing callable and loads nothing -- declarations or data alone
               MULTI_PROGRAM       a SNOBOL4 file carrying more than one top-level END: several programs concatenated, so the
                                   file is not one compilation unit (sbl -bf stops at the first END and never sees the rest)
  PROGRAM    it has an entry point (Icon procedure main; a SNOBOL4 END with no DEFINE-only body; a Prolog initialization(main))
             -- it was never this class's business and is reported, not moved.
  UNDECIDED  none of the above could be measured; reported, never guessed.

  classify <pkgdir> [REL ...]   one line per file: REL<TAB>VERDICT<TAB>KIND<TAB>MEASUREMENT. With no REL, every CONTAINER_OR_LIBRARY
                                row of <pkgdir>/UNGRADABLE.tsv.
  split <pkgdir> [--apply]      moves every CONTAINER_OR_LIBRARY row of UNGRADABLE.tsv by its measurement: a LIBRARY to UNGRADED.tsv
                                as NEEDS_DRIVER, a CONTAINER to CONTAINERS.tsv, and drops the row's OUTSIDE_*.tsv mirror; without
                                --apply it prints the plan. A row measuring neither refuses --apply (rc 2), named.
  verify <pkgdir>               re-measures every row of <pkgdir>/CONTAINERS.tsv (name<TAB>KIND<TAB>measurement; for INCLUDED_BY and
                                OPENED_BY the measurement's first word is the includer or opener). A row whose file is missing,
                                whose KIND is not one of the six, or whose measurement does not re-derive is RED.
                                EXIT 0 all rows re-derive (the count printed), 1 a red row (named), 2 unreadable.
"""
import os, re, sys

EXT_LANG = {'.icn': 'icon', '.sno': 'snobol4', '.spt': 'snobol4', '.inc': 'snobol4', '.pl': 'prolog', '.pro': 'prolog', '.lgt': 'prolog'}
KINDS = ('INCLUDED_BY', 'OPENED_BY', 'LOADED_BY', 'SCAFFOLDING', 'NO_DEFINITION', 'MULTI_PROGRAM')
PL_LOADER = re.compile(r'\b(consult|ensure_loaded|use_module|load_files|reexport)\s*\(')
PL_LOAD = re.compile(r'\b(consult|ensure_loaded|use_module|load_files|logtalk_load|include|reexport)\s*\(')


def lang_of(rel):
    return EXT_LANG.get(os.path.splitext(rel)[1].lower())


def read(path):
    with open(path, 'rb') as f:
        raw = f.read()
    for bom, enc in ((b'\xef\xbb\xbf', 'utf-8'), (b'\xff\xfe\x00\x00', 'utf-32-le'), (b'\x00\x00\xfe\xff', 'utf-32-be'),
                     (b'\xff\xfe', 'utf-16-le'), (b'\xfe\xff', 'utf-16-be')):
        if raw.startswith(bom):
            return raw[len(bom):].decode(enc, 'replace')
    if len(raw) > 3 and raw[1:2] == b'\x00' and raw[3:4] == b'\x00':
        return raw.decode('utf-32-le' if raw[1:4] == b'\x00\x00\x00' else 'utf-16-le', 'replace')
    if len(raw) > 3 and raw[0:1] == b'\x00':
        return raw.decode('utf-32-be' if raw[0:3] == b'\x00\x00\x00' else 'utf-16-be', 'replace')
    return raw.decode('utf-8', 'replace')


def icon_strip(text):
    out = []
    for line in text.split('\n'):
        q, cut = None, len(line)
        i = 0
        while i < len(line):
            c = line[i]
            if q:
                if c == '\\':
                    i += 1
                elif c == q:
                    q = None
            elif c in '"\'':
                q = c
            elif c == '#':
                cut = i
                break
            i += 1
        out.append(line[:cut])
    return '\n'.join(out)


def icon_measure(text):
    t = icon_strip(text)
    procs = re.findall(r'^\s*procedure\s+([A-Za-z_]\w*)', t, re.M)
    recs = re.findall(r'^\s*record\s+([A-Za-z_]\w*)', t, re.M)
    links = [x.strip() for l in re.findall(r'^\s*link\s+(.*)$', t, re.M) for x in l.split(',') if x.strip()]
    incs = re.findall(r'^\s*\$\s*include\s*"?([^"\s#]+)', text, re.M)
    return {'defs': procs + recs, 'procs': procs, 'recs': recs, 'links': links, 'entry': 'main' in procs, 'incs': incs, 'loads': []}


def sno_measure(text):
    body = [l for l in text.split('\n') if l[:1] not in ('*', '#', '|')]
    defs = re.findall(r"\bDEFINE\s*\(\s*['\"]\s*([A-Za-z][\w.]*)", '\n'.join(body), re.I)
    incs = re.findall(r"^-INCLUDE\s+['\"]([^'\"]+)", text, re.M | re.I)
    ends = sum(1 for l in body if re.match(r'END(\s|$)', l))
    has_end = ends > 0
    code = [l for l in body if l.strip() and not re.match(r'-', l) and not re.match(r'END(\s|$)', l)]
    entry = has_end and len(code) > 0 and not defs
    return {'defs': defs, 'entry': entry, 'incs': incs, 'loads': [], 'has_end': has_end, 'ends': ends}


def pl_terms(text):
    """Split Prolog/Logtalk text into terms at an end-dot, skipping comments, quoted atoms/strings and 0'c codes."""
    terms, cur, i, n = [], [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '%':
            j = text.find('\n', i)
            i = n if j < 0 else j
            continue
        if c == '/' and text.startswith('/*', i):
            j = text.find('*/', i + 2)
            i = n if j < 0 else j + 2
            cur.append(' ')
            continue
        if c == '0' and text.startswith("0'", i) and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] == '_')):
            cur.append(text[i:i + 3])
            i += 4 if text.startswith("0'\\", i) or text.startswith("0''", i) else 3
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
            cur.append(text[i:j + 1])
            i = j + 1
            continue
        if c == '.' and (i + 1 >= n or text[i + 1] in ' \t\r\n%') and (not cur or ''.join(cur).rstrip()[-1:] not in '.=:\\<>+-*/^@#&$?~'):
            s = ''.join(cur).strip()
            if s:
                terms.append(s)
            cur = []
            i += 1
            continue
        cur.append(c)
        i += 1
    s = ''.join(cur).strip()
    if s:
        terms.append(s)
    return terms


def pl_measure(text):
    terms = pl_terms(text)
    directives = [t for t in terms if t.startswith(':-') or t.startswith('?-')]
    clauses = [t for t in terms if not (t.startswith(':-') or t.startswith('?-'))]
    incs, loads = [], []
    for d in directives:
        for m in re.finditer(r'\binclude\s*\(\s*([^()]+?)\s*\)', d):
            incs.append(m.group(1).strip().strip("'\""))
        if PL_LOAD.search(d):
            loads.append(d)
    entry = any(re.search(r'initialization\s*\(\s*main\b', d) for d in directives)
    return {'defs': clauses, 'entry': entry, 'incs': incs, 'loads': loads, 'terms': terms}


def measure(path, rel):
    lang = lang_of(rel)
    text = read(path)
    if lang == 'icon':
        return lang, text, icon_measure(text)
    if lang == 'snobol4':
        return lang, text, sno_measure(text)
    if lang == 'prolog':
        return lang, text, pl_measure(text)
    return lang, text, None


class Package:
    def __init__(self, root):
        self.root = os.path.abspath(root)
        self.files = []
        for d, dirs, fs in os.walk(self.root):
            dirs[:] = [x for x in dirs if not x.endswith('.fixtures') and not x.startswith('.')]
            for f in fs:
                rel = os.path.relpath(os.path.join(d, f), self.root)
                if f.startswith('ALL.'):
                    continue  # our own generated rungs concatenates the vendor's files: it is never a shipped includer or opener
                if lang_of(rel) or f == 'tests.in':
                    self.files.append(rel)
        self.files.sort()
        self.by_base = {}
        for r in self.files:
            self.by_base.setdefault(os.path.basename(r), []).append(r)
        self._m = {}
        self._inc = None

    def m(self, rel):
        if rel not in self._m:
            try:
                self._m[rel] = measure(os.path.join(self.root, rel), rel)
            except OSError:
                self._m[rel] = (None, '', None)
        return self._m[rel]

    def resolve(self, includer, target):
        """The package file an include target in <includer> names: from the includer's directory first, else a unique basename."""
        d = os.path.dirname(includer)
        lang = lang_of(includer) or 'snobol4'
        cands = [target]
        if lang == 'prolog' and not os.path.splitext(target)[1]:
            cands = [target + e for e in ('.lgt', '.pl', '.pro')] + [target]
        for c in cands:
            r = os.path.normpath(os.path.join(d, c))
            if r in self.by_base.get(os.path.basename(r), []):
                return r
        for c in cands:
            hits = self.by_base.get(os.path.basename(c), [])
            if len(hits) == 1:
                return hits[0]
        return None

    def includes(self):
        if self._inc is None:
            self._inc = {}
            for r in self.files:
                if os.path.basename(r) == 'tests.in':
                    try:
                        txt = read(os.path.join(self.root, r))
                    except OSError:
                        continue
                    for t in re.findall(r'-L\s*(\S+)', txt):
                        tgt = self.resolve(r, t)
                        if tgt:
                            self._inc.setdefault(tgt, set()).add(r)
                    continue
                lang, _, mm = self.m(r)
                if not mm:
                    continue
                for t in mm['incs']:
                    tgt = self.resolve(r, t)
                    if tgt and tgt != r:
                        self._inc.setdefault(tgt, set()).add(r)
        return self._inc

    def included_defs(self, rel, seen=None):
        """Definitions <rel> pulls in by its include directives, transitively (a textual include splices the included code)."""
        seen = seen if seen is not None else {rel}
        out = []
        mm = self.m(rel)[2] or {}
        for t in mm.get('incs', []):
            tgt = self.resolve(rel, t)
            if tgt and tgt not in seen:
                seen.add(tgt)
                sub = self.m(tgt)[2] or {}
                out += [(tgt, d) for d in sub.get('defs', [])] + self.included_defs(tgt, seen)
        return out

    def _names(self, rel, text):
        stem = os.path.splitext(os.path.basename(rel))[0]
        return re.search(r'(?<![\w/])' + re.escape(stem) + r'(\.\w+)?(?![\w])', text) is not None

    def loaders(self, rel):
        """Package files with a load directive (consult, use_module, logtalk_load ...) naming <rel> by basename or stem."""
        return [r for r in self.files if r != rel and os.path.basename(r) != 'tests.in'
                and any(self._names(rel, l) for l in (self.m(r)[2] or {}).get('loads', []))]

    def pl_loaders(self, rel):
        """Prolog files of the package whose load directive (consult, ensure_loaded, use_module, load_files, reexport -- never
        include, which is INCLUDED_BY) names <rel> by basename or stem: the programs a LOADED_BY module is graded through."""
        return [r for r in self.files if r != rel and os.path.basename(r) != 'tests.in' and self.m(r)[0] == 'prolog'
                and any(PL_LOADER.search(l) and self._names(rel, re.sub(r'\binclude\s*\([^()]*\)', '', l)) for l in (self.m(r)[2] or {}).get('loads', []))]

    def openers(self, rel):
        """Package files that name <rel>'s basename outside any load or include directive -- a data file a test opens."""
        base = os.path.basename(rel)
        out = []
        for r in self.files:
            if r == rel or os.path.basename(r) == 'tests.in':
                continue
            lang, text, mm = self.m(r)
            if base not in text or not mm:
                continue
            if lang == 'prolog':
                if any(base in t for t in mm['terms'] if not (t.startswith(':-') and PL_LOAD.search(t))):
                    out.append(r)
            elif base not in ' '.join(mm['incs']):
                out.append(r)
        return out


def pl_scaffold_loads(mm):
    """The load goals of an initialization directive that loads something: a suite's own loader, whatever helpers it defines."""
    return [d for d in mm['loads'] if re.search(r'initialization\s*\(', d)]


def pl_marker_list(pkg, rel, mm):
    """(n, None) when the file is ONE clause whose body is a conjunction of bare '$use_<module>' goals and every marker is a bare
    fact in a sibling file of its package -- GNU Prolog's link-time reference list (BipsPl/all_pl_bips.pl), which computes nothing and
    names the modules a link must pull in (ceo CEO-1526); else (0, why)."""
    if len(mm['terms']) != 1 or len(mm['defs']) != 1:
        return 0, 'not a single clause'
    m = re.match(r"^'(\$use_[A-Za-z0-9_]+)'\s*:-\s*(.+)$", mm['defs'][0], re.S)
    if not m:
        return 0, 'not a marker rule'
    goals = [g.strip() for g in m.group(2).split(',')]
    marks = [re.fullmatch(r"'(\$use_[A-Za-z0-9_]+)'", g) for g in goals]
    if not goals or not all(marks):
        return 0, 'body is not bare marker goals'
    names = {x.group(1) for x in marks}
    here = os.path.dirname(os.path.join(pkg.root, rel))
    found = set()
    for f in os.listdir(here):
        if f.endswith('.pl') and f != os.path.basename(rel):
            t = open(os.path.join(here, f), encoding='utf-8', errors='replace').read()
            found |= {n for n in names if re.search(r"^'%s'\.\s*$" % re.escape(n), t, re.M)}
    if found != names:
        return 0, '%d marker(s) are no bare fact in a sibling file: %s' % (len(names - found), ' '.join(sorted(names - found))[:80])
    return len(names), None


def classify(pkg, rel):
    path = os.path.join(pkg.root, rel)
    if not os.path.isfile(path):
        return 'UNDECIDED', '-', 'file not shipped'
    lang, _, mm = pkg.m(rel)
    if mm is None:
        return 'UNDECIDED', '-', 'no language for its extension'
    inc = sorted(pkg.includes().get(rel, ()))
    if inc:
        return 'CONTAINER', 'INCLUDED_BY', inc[0]
    if lang == 'snobol4' and mm.get('ends', 0) > 1:
        return 'CONTAINER', 'MULTI_PROGRAM', '%d top-level END statements' % mm['ends']
    if mm['entry']:
        return 'PROGRAM', '-', 'has an entry point (%s)' % {'icon': 'procedure main', 'snobol4': 'END with executable statements and no DEFINE', 'prolog': 'initialization(main)'}[lang]
    idefs = pkg.included_defs(rel)
    if lang == 'prolog':
        if not pkg.loaders(rel) and not any(re.search(r':-|-->', c) for c in mm['defs']):
            # DATA: facts alone, named by a test outside any load directive (the encodings cases open utf_8_bom.lgt and read it).
            # A file of RULES a test names -- swi's data/queens.pl, loaded at run time into temporary modules; save/input/*.pl,
            # compiled into saved states -- is code a program loads, which the ruling calls a library, not data.
            op = pkg.openers(rel)
            if op:
                return 'CONTAINER', 'OPENED_BY', op[0]
        if pl_scaffold_loads(mm) or (not mm['defs'] and not idefs and mm['loads']):
            return 'CONTAINER', 'SCAFFOLDING', ('an initialization directive loads and runs the suite' if pl_scaffold_loads(mm) else 'directives alone, and they load the suite') + (' (%d helper clause(s) beside it)' % len(mm['defs']) if mm['defs'] else '')
        nmark, _why = pl_marker_list(pkg, rel, mm) if lang == 'prolog' else (0, None)
        if nmark:
            return 'CONTAINER', 'SCAFFOLDING', 'one clause of %d bare $use_ marker goals, each a bare fact in a sibling file: a link-time reference list that computes nothing (ceo CEO-1526)' % nmark
        ld = pkg.pl_loaders(rel) if lang == 'prolog' else []
        if (mm['defs'] or idefs) and ld:
            return 'CONTAINER', 'LOADED_BY', sorted(ld)[0]
        if mm['defs'] or idefs:
            own = '%d clause(s)' % len(mm['defs'])
            by = (', %d more by include of %s' % (len(idefs), ' '.join(sorted({t for t, _ in idefs})[:3]))) if idefs else ''
            return 'LIBRARY', 'NEEDS_DRIVER', own + by + ', no initialization(main)'
        return 'CONTAINER', 'NO_DEFINITION', 'no clause and no load directive'
    if lang == 'icon' and (mm['defs'] or mm['links'] or idefs):
        # a record is a callable constructor and a link-only file hands its links to whoever links it (procs/core.icn is ilib's
        # link core): each is a unit a program links, so each is a library owed its driver
        parts = [('%d procedure(s)' % len(mm['procs'])) if mm['procs'] else '', ('%d record(s)' % len(mm['recs'])) if mm['recs'] else '',
                 ('links %s' % ' '.join(mm['links'][:4]) + (' ...' if len(mm['links']) > 4 else '')) if mm['links'] else '',
                 ('%d by $include' % len(idefs)) if idefs else '']
        return 'LIBRARY', 'NEEDS_DRIVER', ', '.join(x for x in parts if x) + ', no procedure main'
    if mm['defs'] or idefs:
        return 'LIBRARY', 'NEEDS_DRIVER', '%d DEFINEd function(s), no entry point: %s' % (len(mm['defs']) + len(idefs), ' '.join(mm['defs'][:4]) + (' ...' if len(mm['defs']) > 4 else ''))
    if lang == 'snobol4' and mm.get('has_end'):
        return 'UNDECIDED', '-', 'an END but nothing measurable around it'
    if lang == 'icon':
        return 'CONTAINER', 'NO_DEFINITION', '0 procedures, 0 records, 0 links -- %s' % ('$define table' if re.search(r'^\s*\$\s*define\b', pkg.m(rel)[1], re.M) else 'a fragment of statements or data')
    return 'CONTAINER', 'NO_DEFINITION', 'no DEFINE and no END'


def tsv_rows(path):
    rows = []
    with open(path, encoding='utf-8') as f:
        for n, line in enumerate(f, 1):
            line = line.rstrip('\n')
            if not line.strip() or line.startswith('#'):
                continue
            rows.append((n, line.split('\t')))
    return rows


SPLIT_TAG = 'util_container_or_library.py, CEO-1272'
PROSE = {
    'INCLUDED_BY': '%s -- its include directive splices this file, which is graded through it and is not a program on its own (%s)',
    'OPENED_BY': '%s -- facts alone, named by that test outside any load directive: a data file it opens and reads (%s)',
    'LOADED_BY': '%s -- its load directive loads this module, which is graded through it and is not a program on its own (%s)',
    'SCAFFOLDING': '%s -- the suite\'s own loader, not a program under test (%s)',
    'NO_DEFINITION': '%s -- defines nothing a program can call, links nothing, and nothing shipped includes it (%s)',
    'MULTI_PROGRAM': '%s -- several programs concatenated in one file, so it is not one compilation unit; sbl -bf stops at the first END (%s)',
}
HDR_CONTAINERS = """# CONTAINERS.tsv -- files this package ships that are NOT PROGRAMS: they leave the shipped population, each named with the
# measurement that makes it one (ceo CEO-1272, 2026-09-25; split out of the retired UNGRADABLE class CONTAINER_OR_LIBRARY by
# SCRIP ../harness/scripts/util_container_or_library.py, which lib_inventory.sh re-runs as `verify` on every inventory -- a row whose
# measurement no longer re-derives refuses the inventory). Columns: name<TAB>KIND<TAB>measurement. KIND is one of INCLUDED_BY,
# OPENED_BY, LOADED_BY (the measurement's first word is the file that splices, opens or loads it), SCAFFOLDING, NO_DEFINITION,
# MULTI_PROGRAM.
# A LIBRARY (callable code, no entry point) is NOT a container: it is UNGRADED NEEDS_DRIVER in UNGRADED.tsv (CEO-1269).
"""
HDR_UNGRADED = """# UNGRADED.tsv -- programs this package ships that are OWED work (name<TAB>CLASS<TAB>reason; lib_inventory.sh's closed vocabulary).
"""


def split(root, apply):
    pkg = Package(root)
    ug = os.path.join(root, 'UNGRADABLE.tsv')
    lines = open(ug, encoding='utf-8').read().split('\n')
    keep, libs, cons, bad = [], [], [], []
    moved = set()
    for line in lines:
        c = line.split('\t')
        if line.strip() and not line.startswith('#') and len(c) > 1 and c[1] == 'CONTAINER_OR_LIBRARY':
            v, k, meas = classify(pkg, c[0])
            if v == 'LIBRARY':
                libs.append('%s\tNEEDS_DRIVER\ta LIBRARY by measurement (%s): %s -- owed its driver, NAME_driver beside it (CEO-1269); was UNGRADABLE CONTAINER_OR_LIBRARY' % (c[0], SPLIT_TAG, meas))
            elif v == 'CONTAINER':
                cons.append('%s\t%s\t%s' % (c[0], k, PROSE[k] % (meas, SPLIT_TAG)))
            else:
                bad.append('%s: %s %s' % (c[0], v, meas))
                keep.append(line)
                continue
            moved.add(c[0])
            continue
        keep.append(line)
    print('SPLIT %s: %d LIBRARY -> UNGRADED.tsv NEEDS_DRIVER, %d CONTAINER -> CONTAINERS.tsv, %d not split' % (root, len(libs), len(cons), len(bad)))
    for b in bad:
        print('  NOT SPLIT (neither a library nor a container by measurement): ' + b)
    if not apply:
        for l in libs + cons:
            print('  ' + l[:200])
        return 1 if bad else 0
    if bad:
        print('REFUSED(2): %d row(s) measured neither -- name them before --apply' % len(bad))
        return 2
    open(ug, 'w', encoding='utf-8').write('\n'.join(keep))
    if libs:
        up = os.path.join(root, 'UNGRADED.tsv')
        cur = open(up, encoding='utf-8').read() if os.path.isfile(up) else HDR_UNGRADED
        open(up, 'w', encoding='utf-8').write(cur.rstrip('\n') + '\n' + '\n'.join(libs) + '\n')
    if cons:
        cp = os.path.join(root, 'CONTAINERS.tsv')
        cur = open(cp, encoding='utf-8').read() if os.path.isfile(cp) else HDR_CONTAINERS
        open(cp, 'w', encoding='utf-8').write(cur.rstrip('\n') + '\n' + '\n'.join(cons) + '\n')
    for f in sorted(os.listdir(root)):
        if f.startswith('OUTSIDE_') and f.endswith('.tsv'):
            op = os.path.join(root, f)
            ol = open(op, encoding='utf-8').read().split('\n')
            nl = [l for l in ol if not (l.split('\t')[0] in moved and len(l.split('\t')) > 1 and l.split('\t')[1] == 'CONTAINER_OR_LIBRARY')]
            if len(nl) != len(ol):
                open(op, 'w', encoding='utf-8').write('\n'.join(nl))
                print('  %s: %d mirror row(s) removed with their UNGRADABLE rows' % (f, len(ol) - len(nl)))
    return 0


def main(argv):
    if len(argv) >= 3 and argv[1] == 'split':
        if not os.path.isfile(os.path.join(argv[2], 'UNGRADABLE.tsv')):
            print('REFUSED(2): %s has no UNGRADABLE.tsv' % argv[2], file=sys.stderr)
            return 2
        return split(argv[2], '--apply' in argv[3:])
    if len(argv) < 3 or argv[1] not in ('classify', 'verify'):
        print(__doc__.split('\n\n')[0], file=sys.stderr)
        print('usage: util_container_or_library.py classify <pkgdir> [REL ...] | verify <pkgdir> | split <pkgdir> [--apply]', file=sys.stderr)
        return 2
    root = argv[2]
    if not os.path.isdir(root):
        print('REFUSED(2): %s is not a package directory' % root, file=sys.stderr)
        return 2
    pkg = Package(root)
    if argv[1] == 'classify':
        rels = argv[3:]
        if not rels:
            ug = os.path.join(root, 'UNGRADABLE.tsv')
            if not os.path.isfile(ug):
                print('REFUSED(2): no REL given and %s is missing' % ug, file=sys.stderr)
                return 2
            rels = [c[0] for _, c in tsv_rows(ug) if len(c) > 1 and c[1] == 'CONTAINER_OR_LIBRARY']
        for rel in rels:
            v, k, meas = classify(pkg, rel)
            print('%s\t%s\t%s\t%s' % (rel, v, k, meas))
        return 0
    ct = os.path.join(root, 'CONTAINERS.tsv')
    if not os.path.isfile(ct):
        print('REFUSED(2): %s is missing' % ct, file=sys.stderr)
        return 2
    red, n = [], 0
    for ln, c in tsv_rows(ct):
        n += 1
        if len(c) < 3:
            red.append('line %d: %d column(s), want name<TAB>KIND<TAB>measurement' % (ln, len(c)))
            continue
        rel, kind, meas = c[0], c[1], (c[2].split() or [''])[0]
        if kind not in KINDS:
            red.append('%s: KIND %r is none of %s -- a class-less or unknown row names no measurement' % (rel, kind, '/'.join(KINDS)))
            continue
        v, k, m = classify(pkg, rel)
        if v != 'CONTAINER' or k != kind:
            red.append('%s: declared %s but measures %s %s (%s)' % (rel, kind, v, k, m))
            continue
        if kind in ('INCLUDED_BY', 'OPENED_BY', 'LOADED_BY'):
            ok = (kind == 'INCLUDED_BY' and meas in pkg.includes().get(rel, ())) or (kind == 'OPENED_BY' and meas in pkg.openers(rel)) \
                or (kind == 'LOADED_BY' and meas in pkg.pl_loaders(rel))
            if not ok:
                red.append('%s: %s %s does not re-derive (measured: %s)' % (rel, kind, meas, m))
                continue
    if red:
        for r in red:
            print('  RED  ' + r)
        print('CONTAINERS VERIFY %s: %d of %d row(s) red' % (root, len(red), n))
        return 1
    print('CONTAINERS VERIFY %s: %d row(s), every one re-derives its measurement' % (root, n))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
