#!/usr/bin/env bash
# test_gate_pl_only_tree_t_crosses_parser_to_lower.sh -- ONLY tree_t CROSSES FROM THE PROLOG PARSER TO THE LOWER STAGE (Lon 2026-09-27
# ~12:3x CDT, in-chat to hq_snocone, verbatim as relayed: "Ensure that only the tree_t gets sent/used by parser stage to the lower stage.
# All global structures needed at runtime, are built in the lower stage."; RULES.md FACT RULE ONLY tree_t CROSSES FROM A PARSER TO THE
# LOWER STAGE; ceo CEO-1322; row prolog-only-tree-t-crosses-from-the-prolog-parser-to-lower-...-lon-2026-09-27).
# ⭐ A LINK-LEVEL RATCHET, NOT A GREP: hq_snocone's audit (findings/FINDING-2026-09-27-hq_snocone-only-tree-t-crosses-parser-to-lower-
# audit-of-the-seven-frontends.md) read the crossings off `nm` over the objects the build links, and so does this gate -- a crossing
# is a symbol one side defines and the other side references, whatever the source spells it. The objects are RT_PIC_SRCS in
# RT_OBJDIR plus the driver object; a missing object REFUSES rc=2 (run `make` first), never passes.
# ARMS:
#   1 no src/lower object references a symbol a src/parsers/prolog object defines, beyond OPEN
#   2 no src/parsers/prolog object references a symbol a src/lower object defines, beyond OPEN
#   3 the symbols a src/parsers/prolog object defines that any object OUTSIDE the parser references are exactly SANCTIONED plus the
#     OPEN names that still cross: SANCTIONED is the parser's entry (prolog_compile, for the driver and polyglot) and the term reader
#     the runtime's read/1 family calls (prolog_parse_ex, and prolog_u_letter, the lexer's letter class the writer quotes by) -- the
#     runtime reading text is a use of the parser as a library, not a crossing to lower. A NEW name reds.
#   4 OPEN ONLY SHRINKS: a name in OPEN that no longer crosses reds, so the landing that cures a crossing removes it from OPEN in the
#     same commit (the ratchet keeps it cured)
#   5 THE CODE_t DETOUR STAYS GONE (cured SCRIP landing A of the row): no CODE_t or STMT_t in src/parsers/prolog, and no parser object
#     references code_to_ast or stmt_to_ast -- the parser builds the statement tree itself
#   6 FAIL-ONCE BUILT IN: the same checker, fed a planted census (a lower object calling a parser function, a parser object calling a
#     lower function, a new outside reference, a cured name still in OPEN, a data global both sides touch), reds on each by name
#   7 NO SHARED REGISTRY: no DATA symbol defined outside the parser is referenced by a src/parsers/prolog object AND by or in a
#     src/lower object, beyond OPEN -- the parser writing a structure the lowerer reads (g_stage2's dynamic set and prelude keys)
#     is the crossing whatever function names carry it
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT" || exit 2
RT_OBJDIR="$(make -s -f Makefile -f <(printf 'p:\n\t@echo $(RT_OBJDIR)\n') p 2>/dev/null)"
DRV_OBJ="$(make -s -f Makefile -f <(printf 'p:\n\t@echo $(OBJ)\n') p 2>/dev/null)/scrip_driver.o"
SRCS="$(make -s -f Makefile -f <(printf 'p:\n\t@echo $(RT_PIC_SRCS)\n') p 2>/dev/null)"
[ -n "$RT_OBJDIR" ] && [ -n "$SRCS" ] || { echo "GATE UNPROVEN(2) [pl_only_tree_t]: cannot read RT_OBJDIR/RT_PIC_SRCS from the Makefile"; exit 2; }
command -v nm > /dev/null || { echo "GATE UNPROVEN(2) [pl_only_tree_t]: nm not found"; exit 2; }
ROOT="$ROOT" RT_OBJDIR="$RT_OBJDIR" DRV_OBJ="$DRV_OBJ" SRCS="$SRCS" python3 - <<'PY'
import os, re, subprocess, sys
ROOT = os.environ['ROOT']
OPEN = {
    'pl_dyn_mark': 'crossing 1, the dynamic-predicate set the parser writes',
    'pl_dyn_is_marked': 'crossing 1, the dynamic-predicate set the parser reads back',
    'pl_prelude_defines': 'crossing 2, lower asks the parser whether the prelude defines a key',
    'g_stage2': 'crossings 1 and 2, the per-compilation struct the parser writes the prelude keys into and lower reads',
    'pl_runtime_clause_tree': 'the clause normalizer lower and the runtime call in the parser',
    'prolog_op_permission': 'crossing 3, the operator table', 'prolog_op_table_add': 'crossing 3, the operator table',
    'prolog_op_table_count': 'crossing 3, the operator table', 'prolog_op_table_get': 'crossing 3, the operator table',
    'prolog_op_user_count': 'crossing 3, the operator table', 'prolog_op_user_get': 'crossing 3, the operator table',
}
SANCTIONED = {'prolog_compile', 'prolog_parse_ex', 'prolog_u_letter', 'prolog_fold_pieces'}
# prolog_fold_pieces (hq_prolog 2026-10-01, the cto's f6f4d0197 made a quoted atom its pieces -- TT_QLIT/TT_CAT/TT_ESC -- and
# left the fold to the lowerer): the term reader the runtime's read/1 family calls (prolog_parse_ex) now hands back pieces, and
# the fold that turns them into the atom's text is the READER'S COMPANION -- the runtime's '$rd' road in by_name_dispatch.c
# calls it on the term it just read, the same use of the parser as a library that prolog_parse_ex and prolog_u_letter are.
# It defines no structure lower reads and reads none the parser writes; it stays out of OPEN because it is not a crossing.
DETOUR = {'code_to_ast', 'stmt_to_ast'}
def group(src):
    if '/src/parsers/prolog/' in src: return 'parser'
    if '/src/lower/' in src: return 'lower'
    return 'outside'
def check(census):
    """census: {name: (group, {'ALL': defined set, 'DATA': defined data set}, undefined set)} -> list of red lines"""
    red = []; pdef = {}; ldef = {}
    for n, (g, d, u) in census.items():
        for s in d['ALL']:
            if g == 'parser': pdef[s] = n
            if g == 'lower': ldef[s] = n
    crossing = {}
    for n, (g, d, u) in census.items():
        if g == 'parser': continue
        for s in u:
            if s in pdef: crossing.setdefault(s, set()).add(n)
    for s, users in sorted(crossing.items()):
        lusers = sorted(x for x in users if census[x][0] == 'lower')
        if lusers and s not in OPEN: red.append('arm 1: lower object(s) %s reference %s, defined in the Prolog parser (%s)' % (','.join(lusers), s, pdef[s]))
        if s not in SANCTIONED and s not in OPEN: red.append('arm 3: %s, defined in the Prolog parser (%s), is referenced outside it by %s -- a new crossing' % (s, pdef[s], ','.join(sorted(users))))
    back = {}
    for n, (g, d, u) in census.items():
        if g != 'parser': continue
        for s in u:
            if s in ldef: back.setdefault(s, set()).add(n)
    for s, users in sorted(back.items()):
        if s not in OPEN: red.append('arm 2: Prolog parser object(s) %s reference %s, defined in a lowerer (%s)' % (','.join(sorted(users)), s, ldef[s]))
    for n, (g, d, u) in census.items():
        if g == 'parser':
            for s in sorted(DETOUR & u): red.append('arm 5: Prolog parser object %s references %s -- the CODE_t detour is back' % (n, s))
    ddef = {}
    for n, (g, d, u) in census.items():
        if g != 'parser':
            for s in d['DATA']: ddef[s] = n
    shared = {}
    for n, (g, d, u) in census.items():
        if g != 'parser': continue
        for s in u:
            if s in ddef:
                lows = sorted(x for x, (g2, d2, u2) in census.items() if g2 == 'lower' and (s in u2 or s in d2['DATA']))
                if lows: shared.setdefault(s, (set(), lows))[0].add(n)
    for s, (users, lows) in sorted(shared.items()):
        if s not in OPEN: red.append('arm 7: data %s (defined in %s) is referenced by Prolog parser object(s) %s and by lowerer(s) %s -- a shared registry' % (s, ddef[s], ','.join(sorted(users)), ','.join(lows)))
    for s in sorted(OPEN):
        if s not in crossing and s not in back and s not in shared: red.append('arm 4: %s (%s) no longer crosses -- remove it from OPEN in this landing' % (s, OPEN[s]))
    return red
def nm(o, flag):
    out = subprocess.run(['nm', flag, o], capture_output=True, text=True).stdout
    r = set(); data = set()
    for line in out.splitlines():
        p = line.split()
        if flag == '-u' and len(p) >= 2: r.add(p[-1])
        elif flag == '--defined-only' and len(p) >= 3 and p[1] in 'TDBRCVWG':
            r.add(p[2])
            if p[1] in 'DBRCVG': data.add(p[2])
    return r if flag == '-u' else {'ALL': r, 'DATA': data}
# arm 6 first: the checker must be able to red
plant = {'lower_x.o': ('lower', {'ALL': {'lx_fn'}, 'DATA': set()}, {'pl_parse_fact', 'g_reg'}),
         'parse_x.o': ('parser', {'ALL': {'pl_parse_fact', 'prolog_compile', 'prolog_atom_name'}, 'DATA': set()}, {'lx_fn', 'code_to_ast', 'g_reg'}),
         'drv.o': ('outside', {'ALL': {'g_reg'}, 'DATA': {'g_reg'}}, {'prolog_compile', 'pl_parse_fact', 'prolog_atom_name'})}
saved = dict(OPEN); OPEN.clear(); OPEN['prolog_atom_name'] = 'planted: still open'; OPEN['pl_prelude_defines'] = 'planted: cured'
got = check(plant); OPEN.clear(); OPEN.update(saved)
want = ['arm 1: lower object(s) lower_x.o reference pl_parse_fact', 'arm 3: pl_parse_fact', 'arm 2: Prolog parser object(s) parse_x.o reference lx_fn', 'arm 5: Prolog parser object parse_x.o references code_to_ast', 'arm 7: data g_reg', 'arm 4: pl_prelude_defines']
miss = [w for w in want if not any(g.startswith(w) for g in got)]
if miss or len(got) != len(want):
    print('GATE FAIL [pl_only_tree_t] arm 6: the checker did not red the planted census by name: missing %s; read %s' % (miss, got)); sys.exit(1)
print('  arm 6 GREEN: a planted census reds on all six arms by name')
srcs = os.environ['SRCS'].split(); objdir = os.path.join(ROOT, os.environ['RT_OBJDIR'])
census = {}; missing = []
for s in srcs:
    b = re.sub(r'\.(c|cpp|cc|s|S)$', '', os.path.basename(s)); o = os.path.join(objdir, b + '.o')
    if not os.path.exists(o): missing.append(o); continue
    census[os.path.basename(s)] = (group(s), nm(o, '--defined-only'), nm(o, '-u'))
drv = os.environ['DRV_OBJ']
if os.path.exists(drv): census['scrip.c'] = ('outside', nm(drv, '--defined-only'), nm(drv, '-u'))
else: missing.append(drv)
nparser = sum(1 for v in census.values() if v[0] == 'parser')
if missing or nparser == 0:
    print('GATE UNPROVEN(2) [pl_only_tree_t]: %d object(s) missing (first %s), %d Prolog parser objects -- run make first' % (len(missing), missing[:1], nparser)); sys.exit(2)
red = check(census)
src_hits = subprocess.run(['grep', '-rnwE', 'CODE_t|STMT_t', 'src/parsers/prolog'], capture_output=True, text=True, cwd=ROOT).stdout.strip()
if src_hits: red.append('arm 5: CODE_t/STMT_t in src/parsers/prolog: ' + src_hits.splitlines()[0])
if red:
    for r in red: print('  RED ' + r)
    print('GATE FAIL [pl_only_tree_t]: %d red over %d objects (%d Prolog parser objects), %d open crossings' % (len(red), len(census), nparser, len(OPEN))); sys.exit(1)
print('GATE PASS [pl_only_tree_t]: %d objects, %d Prolog parser objects; outside the parser only %s and the %d OPEN names cross; lower reads no parser symbol and shares no registry with the parser beyond OPEN; no CODE_t detour'
      % (len(census), nparser, '/'.join(sorted(SANCTIONED)), len(OPEN)))
PY
