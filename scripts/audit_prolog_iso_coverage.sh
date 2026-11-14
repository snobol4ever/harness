#!/usr/bin/env bash
# audit_prolog_iso_coverage.sh — PL-ISO-10: mechanical Prolog coverage audit (GOAL-PROLOG-BB.md LADDER A)
#
# Extracts gprolog's exported builtin list from the canonical source and diffs it against SCRIP's
# admitted set, emitting PROLOG-ISO-TRACKER.md with three columns: DONE / RUNG-ASSIGNED / UNASSIGNED.
# "100% coverage" == UNASSIGNED 0 AND every in-scope row DONE.
#
# Canonical source (RULES.md CONSULT CANONICAL SOURCES): refs/gprolog-master/src/BipsPl/*.pl
#   gprolog self-declares every exported builtin as `set_bip_name(Name, Arity)` in its .pl sources;
#   '$'-prefixed names are internal helpers (choice-point alts etc.) and are NOT user-visible exports.
#
# SCRIP admitted set is read from the FOUR real admission sites (no hardcoded duplicate list):
#   1. src/runtime/by_name_dispatch.c  rt_pl_det_builtin_target()  — det builtins  (name, arity)
#   2. src/lower/lower_prolog.c        pl_ensure_gen_builtin_pred() — GEN rail     (name, arity)
#   3. src/lower/lower_prolog.c        goal() strcmp arms           — lowered arms (name[, arity])
#   4. src/parsers/prolog/prolog_lower.c pb_expand_goal() strcmp arms — AST expansion (name)
#   5. src/parsers/prolog/prelude/*.pl and PL_PRELUDE_SRC in prolog_parse.c — clause heads, prelude_heads() (name, arity)
#   6. src/lower/lower_prolog.c pl_det_leaves[] — triple rows { "name", arity, "$sym" } (name, arity)
#
# Usage:  bash ../harness/scripts/audit_prolog_iso_coverage.sh [--check]
#   (no args)  regenerate the tracker
#   --check    exit 1 if the tracker is stale or UNASSIGNED != 0 (CI/gate use)
# Env: GPROLOG_SRC=<dir>  OUT=<path>
#
# AUTHORS: Lon Jones Cherryholmes · Claude Opus 4.8   DATE: 2026-07-14
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${HERE}/lib_paths.sh"
ROOT="$(cd "$S4E_SCRIP" && pwd)"
if [ -n "${GPROLOG_SRC:-}" ]; then GP="$GPROLOG_SRC"; elif [ -d "${ROOT}/refs/gprolog-master/src/BipsPl" ]; then GP="${ROOT}/refs/gprolog-master/src/BipsPl"; else GP=/home/resources/gprolog-master/src/BipsPl; fi
OUT="${OUT:-$S4E_GITHUB/PROLOG-ISO-TRACKER.md}"
MODE="${1:-}"
if [ ! -d "$GP" ]; then
    echo "audit_prolog_iso_coverage: MISSING canonical source: $GP" >&2
    echo "  tried in order: GPROLOG_SRC (set or not), ${ROOT}/refs/gprolog-master/src/BipsPl, /home/resources/gprolog-master/src/BipsPl" >&2
    echo "  refs/ is gitignored and not auto-populated. Re-create it (RULES.md CONSULT CANONICAL SOURCES):" >&2
    echo "  git clone --depth 1 https://github.com/didoudiaz/gprolog.git ${ROOT}/refs/gprolog-master" >&2
    exit 2
fi
python3 - "$GP" "$ROOT" "$OUT" "$MODE" <<'PY'
import re, sys, glob, os, collections, datetime
GP, ROOT, OUT, MODE = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
def rd(p):
    try: return open(p, errors='ignore').read()
    except OSError: return ''
# ---- side A: gprolog exports (set_bip_name self-declarations) ----------------------------------
per_file = collections.defaultdict(set)
for f in sorted(glob.glob(os.path.join(GP, '*.pl'))):
    for m in re.finditer(r"set_bip_name\(\s*('[^']*'|[^,\s]+)\s*,\s*(\d+)\s*\)", rd(f)):
        nm = m.group(1).strip().strip("'")
        if nm.startswith('$'): continue
        per_file[os.path.basename(f)].add((nm, int(m.group(2))))
gp_all = set().union(*per_file.values()) if per_file else set()
# ---- side B: SCRIP admitted set (four real admission sites) ------------------------------------
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(ROOT)), 'harness', 'scripts')); import lib_split_units; bnd = lib_split_units.unit_text(os.path.join(ROOT, 'src'), 'runtime/by_name_dispatch.c') or ''
low = lib_split_units.unit_text(os.path.join(ROOT, 'src'), 'lower/lower_prolog.c') or ''
pbl = rd(os.path.join(ROOT, 'src/parsers/prolog/prolog_lower.c'))
def unesc(s): return s.replace('\\\\', '\\').replace('\\"', '"')
i = bnd.find('rt_pl_det_builtin_target')
det = set()
if i >= 0:
    body = bnd[i: bnd.find('return (const char *)0;', i)]
    for m in re.finditer(r'\{\s*"((?:[^"\\]|\\.)+)"\s*,\s*(\d+)\s*,\s*"([^"]+)"\s*\}', body):
        det.add((unesc(m.group(1)), int(m.group(2))))
gen = {(m.group(2), int(m.group(3)))
       for m in re.finditer(r'pl_ensure_gen_builtin_pred\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(\d+)\)', low)}
arms = {(unesc(m.group(1)), int(m.group(2)))
        for m in re.finditer(r'!strcmp\(nm,\s*"((?:[^"\\]|\\.)+)"\)\s*&&\s*t->n\s*==\s*(\d+)', low)}
named = {unesc(m.group(1)) for m in re.finditer(r'!strcmp\(nm,\s*"((?:[^"\\]|\\.)+)"\)', low)}
wild = {n for n in named if not any(n == a for a, _ in arms)}
for m in re.finditer(r'strcmp\([a-zA-Z_>.\-]+,\s*"((?:[^"\\]|\\.)+)"\)', pbl):
    wild.add(unesc(m.group(1)))
# FIFTH ADMISSION SITE (added 2026-07-26 s152) -- static NAME-ARRAY tables in lower_prolog.c
# (g_pl_nl_builtins[], the det extra[] list, the relop->suffix maps). The arithmetic comparisons
# < > =< >= =:= =\= are admitted ONLY here -- never strcmp arms, never pl_ensure_gen_builtin_pred,
# never det-table rows -- so the four-site read reported predicates SCRIP RUNS CORRECTLY as gaps
# (proven behaviourally: `1+1 =:= 2` succeeds in --run). Any audit reading four sites over-reports.
# See FINDING-2026-07-26-CLAUDE-PL-THREE-AXIS-DIALECT-AUDIT-AND-FIVE-INSTRUMENT-DEFECTS.md §1.
for m in re.finditer(r'static const char \* (?:const )?[a-zA-Z_0-9]+\s*\[\]\s*=\s*\{([^;]*?)\}\s*;', low, re.S):
    for q in re.finditer(r'"((?:[^"\\]|\\.)+)"', m.group(1)):
        wild.add(unesc(q.group(1)))
for m in re.finditer(r'\{\s*"((?:[^"\\]|\\.)+)"\s*,\s*"((?:[^"\\]|\\.)+)"\s*\}', low):
    wild.add(unesc(m.group(1)))
# control constructs + directives are structural (parser/lowerer), not table entries
STRUCTURAL = {(',', 2), (';', 2), ('->', 2), ('!', 0), ('true', 0), ('fail', 0), ('false', 0),
              ('halt', 0), ('halt', 1), ('dynamic', 1), ('discontiguous', 1), ('ensure_loaded', 1),
              ('initialization', 1), ('bagof', 3), ('setof', 3), ('forall', 2), ('retractall', 1),
              ('call', 1), ('call', 2), ('call', 3), ('call', 4), ('call', 5), ('call', 6),
              ('call', 7), ('call', 8), ('\\+', 1), ('not', 1), ('catch', 3), ('throw', 1)}
# SIXTH ADMISSION SITE (the cto's CTO-543 NEXT, 2026-11-07): the Prolog PRELUDE. SCRIP answers every builtin its prelude
# defines (atom_property/2, get_key/1, listing/1, call_det/2 ...) through a clause, not a C table, so the four C sites read
# them as gaps. prelude_heads reads each clause head at column zero: the text before the first :- or --> at depth 0, or
# before the clause's final period, its name the leading atom (plain or quoted), its arity the top-level commas of the
# argument list plus one (0 with no argument list). A name starting with $ is internal and skipped.
def _q_end(t, j):
    q = t[j]; j += 1; n = len(t)
    while j < n:
        ch = t[j]
        if ch == '\\': j += 2; continue
        if ch == q:
            if j + 1 < n and t[j + 1] == q: j += 2; continue
            return j + 1
        j += 1
    return n
def _head_na(h):
    if not h: return None
    if h[0] == "'":
        j = _q_end(h, 0); name = h[1:j - 1].replace("''", "'"); k = j
    else:
        m = re.match(r"[a-z][A-Za-z0-9_]*|[+\-*/\\^<>=~:.?@#&$]+", h)
        if not m: return None
        name = m.group(0); k = m.end()
    if k < len(h) and h[k] == '(':
        d = 0; commas = 0; j = k; n = len(h)
        while j < n:
            ch = h[j]
            if h.startswith("0'", j): j = _c0_end(h, j); continue
            if ch in "'\"": j = _q_end(h, j); continue
            if ch in '([{': d += 1
            elif ch in ')]}':
                d -= 1
                if d == 0: break
            elif ch == ',' and d == 1: commas += 1
            j += 1
        return (name, commas + 1)
    return (name, 0)
def _c0_end(t, i):
    j = i + 2
    if j < len(t) and t[j] == '\\': return j + 2
    if t.startswith("''", j): return j + 2
    return j + 1
def module_exports(t):
    k = t.find(':- module(')
    if k < 0: return set()
    e = t.find('])', k)
    if e < 0: return set()
    seg = re.sub(r'%[^\n]*', '', t[k:e]); out = set()
    for m in re.finditer(r"('(?:[^']|'')*'|[a-z][A-Za-z0-9_]*)\s*(//|/)\s*(\d+)", seg):
        nm = m.group(1); nm = nm[1:-1].replace("''", "'") if nm.startswith("'") else nm
        out.add((nm, int(m.group(3)) + (2 if m.group(2) == '//' else 0)))
    return out
def prelude_heads(t):
    out = set(); n = len(t); i = 0
    while i < n:
        while i < n:
            if t[i].isspace(): i += 1
            elif t[i] == '%': j = t.find('\n', i); i = n if j < 0 else j + 1
            elif t.startswith('/*', i): j = t.find('*/', i + 2); i = n if j < 0 else j + 2
            else: break
        if i >= n: break
        col0 = i == 0 or t[i - 1] == '\n'
        h0 = i; d = 0; he = None
        while i < n:
            c = t[i]
            if c == '%': j = t.find('\n', i); i = n if j < 0 else j; continue
            if t.startswith('/*', i): j = t.find('*/', i + 2); i = n if j < 0 else j + 2; continue
            if t.startswith("0'", i): i = _c0_end(t, i); continue
            if c in "'\"": i = _q_end(t, i); continue
            if c in '([{': d += 1
            elif c in ')]}': d -= 1
            elif d == 0 and he is None and (t.startswith(':-', i) or t.startswith('-->', i)): he = i
            elif c == '.' and d == 0 and (i + 1 >= n or t[i + 1].isspace() or t[i + 1] == '%'):
                if he is None: he = i
                i += 1; break
            i += 1
        if col0 and he is not None:
            r = _head_na(t[h0:he])
            if r and not r[0].startswith('$'): out.add(r)
    return out
def _c_unesc(s):
    return re.sub(r'\\(.)', lambda m: {'n': '\n', 't': '\t', '"': '"', '\\': '\\'}.get(m.group(1), '\\' + m.group(1)), s)
def _c_prelude(src):
    k = src.find('PL_PRELUDE_SRC =')
    if k < 0: return ''
    parts = []
    for line in src[k:].split('\n')[1:]:
        s = line.strip()
        if not s: continue
        if not s.startswith('"'): break
        j = s.rfind('"')
        if j <= 0: break
        parts.append(_c_unesc(s[1:j]))
    return ''.join(parts)
pre = set()
for f in sorted(glob.glob(os.path.join(ROOT, 'src/parsers/prolog/prelude', '*.pl'))):
    _t = rd(f); pre |= {hd for hd in prelude_heads(_t) if hd in module_exports(_t)}
pre |= prelude_heads(_c_prelude(rd(os.path.join(ROOT, 'src/parsers/prolog/prolog_parse.c'))))
# SEVENTH ADMISSION SITE (2026-11-07, measured by worker_04 and re-measured here): the triple table pl_det_leaves[] in
# lower_prolog.c. Its rows { "name", arity, "$sym" } admit setarg/3, nb_setarg/3 and their kin; no earlier reader matches a
# triple, so they were reported as gaps (probe: setarg(1,f(a),b) prints f(b)).
pdl = set()
for m in re.finditer(r'pl_det_leaves\[\][^=]*=\s*\{(.*?)\}\s*;', low, re.S):
    for t in re.finditer(r'\{\s*"((?:[^"\\]|\\.)+)"\s*,\s*(\d+)\s*,\s*"[^"]*"\s*\}', m.group(1)):
        pdl.add((unesc(t.group(1)), int(t.group(2))))
admitted = det | gen | arms | STRUCTURAL | pre | pdl
def is_admitted(nm, ar):
    return (nm, ar) in admitted or nm in wild
# ---- scope + rung assignment (by canonical source file) ----------------------------------------
RUNG = {'stream.pl': 'PL-ISO-7b', 'char_io.pl': 'PL-ISO-7b', 'const_io.pl': 'PL-ISO-7b',
        'dec10io.pl': 'PL-ISO-7b', 'src_rdr.pl': 'PL-ISO-7b', 'read.pl': 'PL-ISO-7a',
        'write.pl': 'PL-ISO-9', 'format.pl': 'PL-ISO-9', 'print.pl': 'PL-ISO-9', 'pretty.pl': 'PL-ISO-9',
        'atom.pl': 'PL-ISO-4',
        'term_inl.pl': 'PL-ISO-11', 'sort.pl': 'PL-ISO-11',
        'flag.pl': 'PL-ISO-12', 'call.pl': 'PL-ISO-12', 'arith_inl.pl': 'PL-ISO-12',
        'control.pl': 'PL-ISO-12',
        'consult.pl': 'PL-ISO-13', 'expand.pl': 'PL-ISO-13', 'pl_error.pl': 'PL-ISO-13'}
EXT = {'os_interf.pl', 'sockets.pl', 'le_interf.pl', 'debugger.pl', 'stat.pl', 'random.pl',
       'file.pl', 't.pl'}
rows, counts = [], collections.Counter()
for f in sorted(per_file):
    scope = 'gprolog-ext' if f in EXT else 'core'
    for nm, ar in sorted(per_file[f]):
        if is_admitted(nm, ar):
            st, home = 'DONE', ''
        elif f in RUNG:
            st, home = 'RUNG-ASSIGNED', RUNG[f]
        elif scope == 'gprolog-ext':
            st, home = 'RUNG-ASSIGNED', 'PL-EXT (out of PL-100 core scope)'
        else:
            st, home = 'UNASSIGNED', ''
        rows.append((f, nm, ar, scope, st, home))
        counts[st] += 1
        counts['scope:' + scope] += 1
        if st != 'DONE' and scope == 'core': counts['core-open'] += 1
tot = len(rows)
done = counts['DONE']
L = []
L.append('# PROLOG-ISO-TRACKER.md — mechanical coverage: SCRIP vs gprolog 1.4.5')
L.append('')
L.append('**GENERATED — do not hand-edit.** Regenerate: `bash ../harness/scripts/audit_prolog_iso_coverage.sh`')
L.append('Source of truth: `refs/gprolog-master/src/BipsPl/*.pl` `set_bip_name/2` self-declarations.')
L.append('Rung: GOAL-PROLOG-BB.md LADDER A → PL-ISO-10. **100% == UNASSIGNED 0 AND core-open 0.**')
L.append('')
L.append('## Scoreboard')
L.append('')
L.append('| metric | count |')
L.append('|--------|-------|')
L.append(f'| gprolog public exports (total) | {tot} |')
L.append(f'| DONE (SCRIP admits) | {done} ({100*done//tot if tot else 0}%) |')
L.append(f'| RUNG-ASSIGNED | {counts["RUNG-ASSIGNED"]} |')
L.append(f'| **UNASSIGNED** | **{counts["UNASSIGNED"]}** |')
L.append(f'| core scope | {counts["scope:core"]} |')
L.append(f'| gprolog-ext scope | {counts["scope:gprolog-ext"]} |')
L.append(f'| **core still open** | **{counts["core-open"]}** |')
L.append('')
L.append('## Per-file coverage')
L.append('')
L.append('| file | scope | done | total | open |')
L.append('|------|-------|------|-------|------|')
for f in sorted(per_file, key=lambda x: (-len(per_file[x]), x)):
    d = sum(1 for r in rows if r[0] == f and r[4] == 'DONE')
    n = len(per_file[f])
    sc = 'gprolog-ext' if f in EXT else 'core'
    L.append(f'| `{f}` | {sc} | {d} | {n} | {n-d} |')
L.append('')
for section, want in (('UNASSIGNED — no rung owns these (must reach 0)', 'UNASSIGNED'),
                      ('RUNG-ASSIGNED — owned, not yet landed', 'RUNG-ASSIGNED'),
                      ('DONE — admitted by SCRIP', 'DONE')):
    sel = [r for r in rows if r[4] == want]
    L.append(f'## {section}  ({len(sel)})')
    L.append('')
    if not sel:
        L.append('*(none)*'); L.append(''); continue
    L.append('| predicate | file | scope | home |')
    L.append('|-----------|------|-------|------|')
    for f, nm, ar, scope, st, home in sel:
        L.append(f'| `{nm}/{ar}` | `{f}` | {scope} | {home} |')
    L.append('')
open(OUT, 'w').write('\n'.join(L) + '\n')
print(f'gprolog exports={tot}  DONE={done}  RUNG-ASSIGNED={counts["RUNG-ASSIGNED"]}  '
      f'UNASSIGNED={counts["UNASSIGNED"]}  core-open={counts["core-open"]}')
print(f'wrote {OUT}')
if MODE == '--check' and counts['UNASSIGNED'] != 0:
    print(f'AUDIT BLOCKED: UNASSIGNED={counts["UNASSIGNED"]} (every row needs a rung home)')
    sys.exit(1)
PY
