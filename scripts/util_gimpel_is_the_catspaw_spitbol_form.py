#!/usr/bin/env python3
# util_gimpel_is_the_catspaw_spitbol_form.py -- Lon 2026-09-27 ~12:0x CDT, in-chat to the ceo, verbatim: "Use the *.inc names
# exclusively. Ensure we have the SPITBOL dialect from the Mark Emmer's distribution, and not the SNOBOL4 dialect." (CEO-1319)
# The vendored Gimpel package must be Catspaw's (Mark Emmer's) Algorithms-in-SNOBOL4 distribution v1.06, its \SPITBOL form,
# kept at /home/resources/gimpel/SPITBOL -- never its \SNOBOL4 (SNOBOL4+) form and never a fleet edit. Four checks, each named:
#   FORM     every file of the \SPITBOL form is vendored under its own name LOWER-CASED (NAME.INC -> name.inc, ASM.SPT -> asm.spt,
#            PHRASES.IN -> phrases.in) and equals it with only CR and ^Z dropped and trailing blanks dropped: all 61 of the form's
#            -INCLUDE targets and its INPUT file names are spelled lower-case, so lower-cased names make the sources run verbatim on a
#            case-sensitive file system with no edit to any line (the two DOS 8.3 names, stringout.inc and resolution.inc, are LOCAL.tsv)
#            ⭐ Lon, same sitting, verbatim: "So we should vendor all SPITBOL-form files verbatum, with only uppercase keywords/reserved-
#            words for SCRIP acceptance." and "And any other edit required to get running under Linux." -- so a file MAY differ from the
#            form, and only when EDITS.tsv declares it (file<TAB>class<TAB>lines<TAB>reason), each class checked mechanically:
#              RESERVED_UPPER  every changed token differs from the form's only by case, is a SPITBOL reserved word or &keyword, and
#                              is upper-case in the vendored file; string literals and every other byte are unchanged
#              LINUX           the lines that differ are EXACTLY the declared line numbers (vendored numbering), reason mandatory
#              COMMENTED_OUT   each declared line is EXACTLY the form's line behind a leading '*', and no other line differs
#                              for it: Catspaw's own unfinished commenting-out completed where SPITBOL rejects the file (Lon
#                              2026-10-02, in-chat to the ceo, verbatim: "Find out why and fix why SPITBOL rejects these
#                              programs."; ceo CEO-1413)
#   NOTHING  every other vendored file is a driver's own (NAME_driver.sno/.ref/.input/.in), a sidecar the runner or the
#            inventory reads (ALL.*, *.tsv, README.md, PROVENANCE.md), or declared in LOCAL.tsv (name<TAB>reason)
#   NAMES    no library or program is named *.sno or with an upper-case extension: *.inc exclusively, a program *.spt
#   KEYS     the newest gimpel pass in the progress DB keys no library or program by a .sno name
# rc 0 all four hold, rc 1 any fails (each failure named), rc 2 cannot measure.
import difflib, os, re, sys
home = os.environ.get('S4E_HOME') or os.path.dirname(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP"))
V = os.path.join(home, 'corpus', 'packages', 'snobol4', 'gimpel')
SP = os.environ.get('GIMPEL_SPITBOL_FORM', '/home/resources/gimpel/SPITBOL')
DB = os.environ.get('S4E_PROGRESS_DB', '/home/resources/progress/results.tsv')
if not os.path.isdir(V) or not os.path.isdir(SP) or not os.path.isfile(DB):
    print('REFUSE(2): cannot see the package %s, the Catspaw SPITBOL form %s or the progress DB %s' % (V, SP, DB)); sys.exit(2)
def norm(p):
    t = open(p, 'rb').read().replace(b'\r', b'').replace(b'\x1a', b'').decode('latin-1')
    return [l.rstrip() for l in t.rstrip('\n ').split('\n')]
bad = {'FORM': [], 'NOTHING': [], 'NAMES': [], 'KEYS': []}
form = sorted(f for f in os.listdir(SP) if not f.upper().startswith('README'))
if not form: print('REFUSE(2): the SPITBOL form directory is empty'); sys.exit(2)
vend = set(os.listdir(V))
RES = set('''OUTPUT INPUT TERMINAL PUNCH DEFINE SIZE DUPL TRIM IDENT DIFFER EQ NE LT GT LE GE SPAN BREAK BREAKX ANY NOTANY LEN POS
RPOS TAB RTAB ARB BAL REM FAIL FENCE SUCCEED ABORT CONVERT DATATYPE ARRAY TABLE DATA ITEM OPSYN APPLY SUBSTR REPLACE REVERSE LPAD RPAD
INTEGER REMDR RETURN FRETURN NRETURN END ENDFILE DETACH REWIND EVAL CODE LOAD UNLOAD CHAR LGT LEQ LNE LGE LLE LLT ARBNO COPY FIELD
PROTOTYPE SORT RSORT EXP LN SQRT SIN COS TAN ATAN CHOP HOST DATE TIME COLLECT DUMP SETEXIT STOPTR TRACE EXIT BACKSPACE CONTINUE
SCONTINUE VALUE CLEAR NUMERIC REAL STRING PATTERN NAME EXPRESSION
INCLUDE COPY LIST UNLIST EJECT TITLE STITL CASE NOCASE NOFAIL ERRORS NOERRORS EXECUTE NOEXECUTE PRINT NOPRINT SPACE LINE'''.split())
tok = re.compile(r"'[^']*'|\"[^\"]*\"|&?[A-Za-z][A-Za-z0-9_.]*|.")
edits = {}
et = os.path.join(V, 'EDITS.tsv')
if os.path.isfile(et):
    for l in open(et, encoding='utf-8'):
        if not l.strip() or l.startswith('#'): continue
        c = l.rstrip('\n').split('\t')
        if len(c) < 4 or c[1] not in ('RESERVED_UPPER', 'LINUX', 'COMMENTED_OUT') or not c[3].strip(): bad['FORM'].append('EDITS.tsv row malformed or reasonless: ' + l.strip()[:60]); continue
        edits.setdefault(c[0], []).append((c[1], {int(x) for x in c[2].split(',') if x.strip().isdigit()}))
def upper_ok(a, b):
    ta, tb = tok.findall(a), tok.findall(b)
    if len(ta) != len(tb): return False
    for x, y in zip(ta, tb):
        if x == y: continue
        if x.upper() != y.upper() or x[:1] in '\'"' or y != y.upper(): return False
        if not (y.startswith('&') or y in RES): return False
    return True
for f in form:
    v = f.lower()
    if v not in vend: bad['FORM'].append(v + ' absent'); continue
    A, B = norm(os.path.join(SP, f)), norm(os.path.join(V, v))
    if A == B:
        if v in edits: bad['FORM'].append(v + ' declared in EDITS.tsv but identical to the form')
        continue
    ed = edits.get(v)
    if not ed: bad['FORM'].append(v + ' differs, no EDITS.tsv row'); continue
    linux = set().union(*[s for k, s in ed if k == 'LINUX']); upper = any(k == 'RESERVED_UPPER' for k, s in ed)
    cmt = set().union(*[s for k, s in ed if k == 'COMMENTED_OUT']); seen_cmt = set()
    changed = set()
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, A, B, autojunk=False).get_opcodes():
        if op == 'equal': continue
        if op == 'replace' and i2 - i1 == j2 - j1 and upper and all(upper_ok(A[i1 + k], B[j1 + k]) for k in range(i2 - i1)): continue
        if op == 'replace' and i2 - i1 == j2 - j1 and all(j1 + k + 1 in cmt and B[j1 + k] == '*' + A[i1 + k] for k in range(i2 - i1)): seen_cmt |= set(range(j1 + 1, j2 + 1)); continue
        changed |= set(range(j1 + 1, max(j2, j1 + 1) + 1)) if op != 'delete' else {j1 + 1}
    if changed != linux: bad['FORM'].append('%s LINUX lines %s declared, %s differ' % (v, sorted(linux), sorted(changed)))
    if seen_cmt != cmt: bad['FORM'].append('%s COMMENTED_OUT lines %s declared, %s are the form\'s line behind a * ' % (v, sorted(cmt), sorted(seen_cmt)))
local = set()
lt = os.path.join(V, 'LOCAL.tsv')
if os.path.isfile(lt):
    for l in open(lt, encoding='utf-8'):
        if l.strip() and not l.startswith('#'):
            n, _, why = l.rstrip('\n').partition('\t')
            if why.strip(): local.add(n)
            else: bad['NOTHING'].append(n + ' declared in LOCAL.tsv with no reason')
side = re.compile(r'^(ALL\..*|.*\.tsv|README\.md|PROVENANCE\.md|\.gitkeep)$')
drv = re.compile(r'^[A-Za-z0-9_]+_driver\.(sno|ref|input|in|IN|wantrc)$')
fset = {f.lower() for f in form}
for f in sorted(vend):
    if f in fset or f in local or side.match(f) or drv.match(f): continue
    bad['NOTHING'].append(f)
for f in sorted(vend):
    if side.match(f) or drv.match(f): continue
    if f.endswith('.sno') or re.search(r'\.[A-Z]+$', f): bad['NAMES'].append(f)
rows = []
with open(DB, 'rb') as fh:
    fh.seek(0, 2); fh.seek(max(0, fh.tell() - 60_000_000))
    for raw in fh:
        c = raw.decode('utf-8', 'replace').rstrip('\n').split('\t')
        if len(c) > 7 and c[5] == 'gimpel' and c[4] == 'package': rows.append(c)
if not rows: bad['KEYS'].append('no gimpel package row in the newest 60 MB of the progress DB -- run the gimpel pass')
else:
    last = max(r[0] for r in rows)[:13]
    keys = sorted({r[7] for r in rows if r[0][:13] == last})
    bad['KEYS'] += [k + ' (pass of ' + last + 'h)' for k in keys if k.endswith('.sno') and not k.endswith('_driver.sno')]
ok = True
for k in ('FORM', 'NOTHING', 'NAMES', 'KEYS'):
    if bad[k]:
        ok = False; print('RED %-7s %d: %s' % (k, len(bad[k]), ' '.join(bad[k][:12]) + (' ...' if len(bad[k]) > 12 else '')))
    else: print('ok  %s' % k)
print(('GREEN' if ok else 'RED') + ': gimpel is %sCatspaw\'s (Mark Emmer\'s) SPITBOL form, %d files of %s' % ('' if ok else 'NOT YET ', len(form), SP))
sys.exit(0 if ok else 1)
