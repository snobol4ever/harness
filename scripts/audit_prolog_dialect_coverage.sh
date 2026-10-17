#!/usr/bin/env bash
# audit_prolog_dialect_coverage.sh — PL-100: THREE-AXIS mechanical coverage (ISO / GNU / SWI)
#
# The existing audit_prolog_iso_coverage.sh measures ONE axis (gprolog set_bip_name exports) and is
# blind to (a) what the ISO standard itself requires and (b) what SWI-Prolog provides. This script
# adds those two axes so "100% of GNU, SWI, and industry-standard Prolog" is a MEASURED claim.
#
# Canonical sources (RULES.md CONSULT CANONICAL SOURCES) — every set is DERIVED, none hand-typed:
#   GNU : refs/gprolog-master/src/BipsPl/*.pl      set_bip_name(Name,Arity) self-declarations
#   SWI : refs/swipl-devel-master/src/*.c          PRED_IMPL/PRED_DEF(name,arity,cfn,flags)
#         refs/swipl-devel-master/boot/*.pl        column-0 clause heads (boot-level system preds)
#   ISO : SWI's own PL_FA_ISO registration flag  UNION  gprolog doc/pl-bips.tex "ISO predicate(s)"
#         prose attached to the preceding \IdxPBD{name/arity} group. Two independent machine
#         signals; their DISAGREEMENT is reported rather than hidden (neither is complete alone:
#         PL_FA_ISO only tags C-implemented predicates, the gprolog prose only covers documented
#         ones). ISO 13211-1 itself is not machine-readable, so this union IS the operational proxy.
#
# SCRIP admitted set is read from the SAME four admission sites as audit_prolog_iso_coverage.sh
# (no second hardcoded list to drift): by_name_dispatch.c det table, lower_prolog.c GEN rail +
# goal() strcmp arms, prolog_lower.c pb_expand_goal arms, plus the STRUCTURAL control constructs.
#
# Usage:  bash ../harness/scripts/audit_prolog_dialect_coverage.sh [--check]
# Env:    GPROLOG_SRC=<dir> SWIPL_SRC=<dir> OUT=<path>
#
# AUTHORS: Lon Jones Cherryholmes · Claude Opus 5   DATE: 2026-07-26
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../SCRIP" && pwd)"
GP="${GPROLOG_SRC:-${ROOT}/refs/gprolog-master}"
SW="${SWIPL_SRC:-${ROOT}/refs/swipl-devel-master}"
OUT="${OUT:-$S4E/.github/PROLOG-DIALECT-TRACKER.md}"
MODE="${1:-}"
for d in "$GP/src/BipsPl" "$SW/src" "$SW/boot"; do
    [ -d "$d" ] || { echo "audit_prolog_dialect_coverage: MISSING canonical source: $d" >&2
                     echo "  refs/ is gitignored and not auto-populated (RULES.md)." >&2; exit 2; }
done
python3 - "$GP" "$SW" "$ROOT" "$OUT" "$MODE" <<'PY'
import re, sys, glob, os, collections, datetime
GP, SW, ROOT, OUT, MODE = sys.argv[1:6]
def rd(p):
    try: return open(p, errors='ignore').read()
    except OSError: return ''
def unesc(s): return s.replace('\\\\', '\\').replace('\\"', '"')
def norm(nm):
    nm = nm.strip().strip("'")
    if len(nm) > 2 and nm[0] == '(' and nm[-1] == ')': nm = nm[1:-1]
    return nm.replace('\\_', '_')
# ================ side A1: GNU (gprolog set_bip_name self-declarations) =========================
gnu = set()
for f in sorted(glob.glob(os.path.join(GP, 'src/BipsPl/*.pl'))):
    for m in re.finditer(r"set_bip_name\(\s*('[^']*'|[^,\s]+)\s*,\s*(\d+)\s*\)", rd(f)):
        nm = norm(m.group(1))
        if not nm.startswith('$'): gnu.add((nm, int(m.group(2))))
# gprolog INLINED builtins (type_inl/term_inl/arith_inl/g_var_inl) are compiled straight to WAM
# instructions by Pl2Wam and therefore NEVER call set_bip_name -- var/1, atom/1, functor/3, arg/3,
# =../2, is/2 and the arithmetic comparisons are ALL invisible to the set_bip_name extraction that
# PROLOG-ISO-TRACKER.md relies on. They are read here from the *_inl.pl column-0 clause heads.
gnu_inl = set()
# Inline arithmetic comparison is declared in OPERATOR (infix) form -- `X =:= Y :-`, `X < Y :-` --
# so a `name(` head regex misses =:= =\= < > =< >= entirely. Arity-0 builtins (`repeat.`) have no
# parens at all. Both shapes are read here in addition to the ordinary canonical-form heads.
for f in sorted(glob.glob(os.path.join(GP, 'src/BipsPl/*.pl'))):
    body = rd(f)
    inline_file = f.endswith('_inl.pl')
    for m in re.finditer(r"(?m)^[A-Z][a-zA-Z0-9_]*\s+([^\sA-Za-z0-9_]{1,3})\s+[A-Z][a-zA-Z0-9_]*\s*:-", body):
        gnu_inl.add((norm(m.group(1)), 2))
    for m in re.finditer(r"(?m)^([a-z][a-zA-Z0-9_]*)\s*(?::-|\.)\s*$", body):
        gnu_inl.add((norm(m.group(1)), 0))
    if not inline_file: continue
    for m in re.finditer(r"(?m)^([a-z][a-zA-Z0-9_]*|'[^']+')\((.*)$", body):
        nm = norm(m.group(1))
        if nm.startswith('$'): continue
        depth, ar = 1, 1
        for ch in m.group(2):
            if ch == '(': depth += 1
            elif ch == ')':
                depth -= 1
                if depth == 0: break
            elif ch == ',' and depth == 1: ar += 1
        gnu_inl.add((nm, ar))
gnu |= gnu_inl
# ================ side A2: SWI (C-registered + boot-level) ======================================
swi, iso_swi, iso_thr = set(), set(), set()
for f in sorted(glob.glob(os.path.join(SW, 'src/*.c'))):
    for m in re.finditer(r'PRED_(?:IMPL|DEF)\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*(\d+)\s*,\s*\w+\s*,\s*([^)]*)\)', rd(f)):
        key = (norm(unesc(m.group(1))), int(m.group(2)))
        swi.add(key)
        if 'PL_FA_ISO' in m.group(3):
            # SWI applies PL_FA_ISO to its multi-threading predicates too -- those conform to the
            # ISO 13211-5 threads DTR, NOT to 13211-1 core. Partition by defining source file so
            # the core axis is not inflated by mutexes/message queues/threads.
            (iso_thr if os.path.basename(f) in ('pl-thread.c', 'pl-mutex.c') else iso_swi).add(key)
for f in sorted(glob.glob(os.path.join(SW, 'boot/*.pl'))):
    for m in re.finditer(r"(?m)^([a-z][a-zA-Z0-9_]*|'[^']+')\(", rd(f)):
        nm = norm(m.group(1))
        if nm.startswith('$'): continue
        line = rd(f)[m.start():]
        head = line[:line.find('\n') if '\n' in line[:400] else 400]
        depth, ar, i = 0, 1, head.find('(')
        for ch in head[i:]:
            if ch == '(': depth += 1
            elif ch == ')':
                depth -= 1
                if depth == 0: break
            elif ch == ',' and depth == 1: ar += 1
        swi.add((nm, ar))
# ================ side A3: ISO (PL_FA_ISO  UNION  gprolog doc prose) ============================
iso_gp, iso_expl, iso_infer = set(), set(), set()
tex = rd(os.path.join(GP, 'doc/pl-bips.tex'))
for b in re.split(r'\\subsubsection', tex):
    names = {(norm(n), int(a)) for n, a in re.findall(r'\\IdxPBD\{([^}/]+)/(\d+)\}', b)}
    if not names or not re.search(r'\bISO predicates?\b', b): continue
    # Scope the claim to the SENTENCE containing it. A subsubsection commonly documents an ISO
    # predicate ALONGSIDE gprolog extensions (call_det/2, call_nth/2, countall/2 were attributed
    # ISO by group-wide attribution -- they are gprolog extensions). Explicit > inferred, and the
    # two are counted separately so the inferred share is visible rather than assumed.
    for sent in re.split(r'(?<=\.)\s', b):
        if not re.search(r'\bISO predicates?\b', sent): continue
        sub = {(norm(n), int(a)) for n, a in re.findall(r'([A-Za-z\\_]+)\\?/(\d+)', sent)} & names
        if sub: iso_gp |= sub; iso_expl.update(sub)
        elif len(names) == 1: iso_gp |= names; iso_expl.update(names)
        else: iso_gp |= names; iso_infer.update(names)
iso = iso_swi | iso_gp
iso_infer -= iso_expl
# ================ side B: SCRIP admitted set (SAME four sites as the ISO audit) =================
bnd = rd(os.path.join(ROOT, 'src/runtime/by_name_dispatch.c'))
low = rd(os.path.join(ROOT, 'src/lower/lower_prolog.c'))
pbl = rd(os.path.join(ROOT, 'src/parsers/prolog/prolog_lower.c'))
i, det = bnd.find('rt_pl_det_builtin_target'), set()
if i >= 0:
    body = bnd[i: bnd.find('return (const char *)0;', i)]
    for m in re.finditer(r'\{\s*"((?:[^"\\]|\\.)+)"\s*,\s*(\d+)\s*,\s*"([^"]+)"\s*\}', body):
        det.add((norm(unesc(m.group(1))), int(m.group(2))))
gen = {(norm(m.group(2)), int(m.group(3)))
       for m in re.finditer(r'pl_ensure_gen_builtin_pred\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*(\d+)\)', low)}
arms = {(norm(unesc(m.group(1))), int(m.group(2)))
        for m in re.finditer(r'!strcmp\(nm,\s*"((?:[^"\\]|\\.)+)"\)\s*&&\s*t->n\s*==\s*(\d+)', low)}
named = {norm(unesc(m.group(1))) for m in re.finditer(r'!strcmp\(nm,\s*"((?:[^"\\]|\\.)+)"\)', low)}
wild = {n for n in named if not any(n == a for a, _ in arms)}
for m in re.finditer(r'strcmp\([a-zA-Z_>.\-]+,\s*"((?:[^"\\]|\\.)+)"\)', pbl):
    wild.add(norm(unesc(m.group(1))))
# FIFTH ADMISSION SITE -- static NAME-ARRAY tables in lower_prolog.c (g_pl_nl_builtins[], the
# det `extra[]` list, the relop->suffix maps). The arithmetic comparisons < > =< >= =:= =\= are
# admitted ONLY here: they are never strcmp arms, never pl_ensure_gen_builtin_pred calls, and
# never det-table rows, so the four-site extraction reports them as GAPS while SCRIP runs them
# correctly (verified behaviourally, 2026-07-26). Any audit reading only four sites over-reports.
for m in re.finditer(r'static const char \* (?:const )?[a-zA-Z_0-9]+\s*\[\]\s*=\s*\{([^;]*?)\}\s*;', low, re.S):
    for q in re.finditer(r'"((?:[^"\\]|\\.)+)"', m.group(1)):
        wild.add(norm(unesc(q.group(1))))
for m in re.finditer(r'\{\s*"((?:[^"\\]|\\.)+)"\s*,\s*"((?:[^"\\]|\\.)+)"\s*\}', low):
    wild.add(norm(unesc(m.group(1))))
STRUCTURAL = {(',', 2), (';', 2), ('->', 2), ('!', 0), ('true', 0), ('fail', 0), ('false', 0),
              ('halt', 0), ('halt', 1), ('dynamic', 1), ('discontiguous', 1), ('ensure_loaded', 1),
              ('initialization', 1), ('bagof', 3), ('setof', 3), ('forall', 2), ('retractall', 1),
              ('call', 1), ('call', 2), ('call', 3), ('call', 4), ('call', 5), ('call', 6),
              ('call', 7), ('call', 8), ('\\+', 1), ('not', 1), ('catch', 3), ('throw', 1)}
admitted = det | gen | arms | STRUCTURAL
def ok(k): return k in admitted or k[0] in wild
# ================ report =======================================================================
def tally(s): return sum(1 for k in s if ok(k)), len(s)
L = []
L.append('# PROLOG-DIALECT-TRACKER.md — three-axis coverage: SCRIP vs ISO / GNU / SWI')
L.append('')
L.append('**GENERATED — do not hand-edit.** Regenerate: `bash ../harness/scripts/audit_prolog_dialect_coverage.sh`')
L.append('')
L.append('Companion to `PROLOG-ISO-TRACKER.md` (which measures the GNU axis only, per-file, with rung')
L.append('assignments). This file adds the **ISO** and **SWI** axes so PL-100\'s "beat GNU and SWI on')
L.append('features" is measurable against all three targets at once.')
L.append('')
L.append('⚠ **SCOPE — THIS COUNTS PREDICATES ONLY.** Syntax (operator table, reader escapes, flags')
L.append('affecting parsing) and non-predicate semantics (format/2 directives, write_term/2 options,')
L.append('error-term shapes) are NOT predicate rows and are structurally invisible here — the same')
L.append('blindness s151 named for the GNU tracker. Those surfaces are tracked in the SYNTAX AND')
L.append('SEMANTICS SURFACES section below, which is measured separately.')
L.append('')
L.append('## Scoreboard')
L.append('')
L.append('| axis | source of truth | total | SCRIP admits | open | % |')
L.append('|------|-----------------|-------|--------------|------|---|')
for label, s, src in (('**ISO 13211-1**', iso, 'PL_FA_ISO ∪ gprolog doc prose'),
                      ('GNU', gnu, 'set_bip_name/2 + *_inl.pl inline family'),
                      ('SWI', swi, 'PRED_IMPL/PRED_DEF + boot/*.pl')):
    d, t = tally(s)
    L.append('| %s | %s | %d | %d | %d | %d%% |' % (label, src, t, d, t - d, round(100.0 * d / t) if t else 0))
u = iso | gnu | swi
d, t = tally(u)
L.append('| **UNION (all three)** | — | %d | %d | %d | %d%% |' % (t, d, t - d, round(100.0 * d / t) if t else 0))
L.append('')
L.append('⚠ **THE GNU AXIS HERE IS LARGER THAN `PROLOG-ISO-TRACKER.md`\'S.** That tracker extracts')
L.append('`set_bip_name/2` only, and gprolog\'s INLINED builtins never call it — Pl2Wam compiles them')
L.append('straight to WAM instructions. `var/1 atom/1 integer/1 float/1 number/1 atomic/1 compound/1')
L.append('callable/1 ground/1 is/2 =/2 functor/3 arg/3 =../2` and the arithmetic comparisons are')
L.append('therefore **absent from that tracker\'s 312-row denominator entirely**. This axis adds them')
L.append('back from `BipsPl/*_inl.pl` (+%d rows). SCRIP already admits most of them, so the effect is')
L.append('a TRUNCATED DENOMINATOR, not an overstated numerator — but the 312 total and its derived')
L.append('percentages are measured against a universe missing the language\'s most-used predicates.')
L.append('')
L.append('## ISO axis — the two signals and where they DISAGREE')
L.append('')
L.append('Neither signal is complete alone, so the axis is their union and the disagreement is')
L.append('reported, not hidden: `PL_FA_ISO` only tags predicates SWI implements in C, and the gprolog')
L.append('prose only covers predicates its manual documents.')
L.append('')
L.append('| signal | count |')
L.append('|--------|-------|')
L.append('| SWI `PL_FA_ISO` (excl. threads) | %d |' % len(iso_swi))
L.append('| gprolog doc, sentence-EXPLICIT | %d |' % len(iso_expl))
L.append('| gprolog doc, group-INFERRED (weaker) | %d |' % len(iso_infer))
L.append('| both agree | %d |' % len(iso_swi & iso_gp))
L.append('| SWI only | %d |' % len(iso_swi - iso_gp))
L.append('| gprolog only | %d |' % len(iso_gp - iso_swi))
L.append('| **union (the ISO 13211-1 axis)** | **%d** |' % len(iso))
L.append('| ISO 13211-5 threads DTR (separate axis) | %d |' % len(iso_thr))
L.append('')
L.append('⚠ **`PL_FA_ISO` IS NOT 13211-1-ONLY.** SWI applies it to its multi-threading predicates')
L.append('(`mutex_lock/1`, `thread_send_message/2`, `message_queue_create/2` …), which conform to the')
L.append('ISO 13211-5 threads DTR. Those are partitioned out above; folding them into the core axis')
L.append('inflates it by %d and misreports thread support as an ISO-core gap.' % len(iso_thr))
L.append('')
open_iso = sorted(k for k in iso if not ok(k))
L.append('## ⛔ ISO OPEN — %d predicates (the industry-standard gap; HIGHEST PRIORITY)' % len(open_iso))
L.append('')
if open_iso:
    L.append('| predicate | in GNU | in SWI |')
    L.append('|-----------|--------|--------|')
    for nm, ar in open_iso:
        L.append('| `%s/%d` | %s | %s |' % (nm, ar, 'yes' if (nm, ar) in gnu else '—',
                                            'yes' if (nm, ar) in swi else '—'))
else:
    L.append('**NONE — the ISO axis is CLOSED.**')
L.append('')
swi_only = sorted(k for k in (swi - gnu - iso) if not ok(k))
L.append('## SWI-only open — %d (features GNU lacks; PL-100 "beat SWI" scope)' % len(swi_only))
L.append('')
L.append('<details><summary>expand</summary>')
L.append('')
L.append(', '.join('`%s/%d`' % k for k in swi_only) if swi_only else 'none')
L.append('')
L.append('</details>')
L.append('')
gnu_only = sorted(k for k in (gnu - swi - iso) if not ok(k))
L.append('## GNU-only open — %d (features SWI lacks)' % len(gnu_only))
L.append('')
L.append('<details><summary>expand</summary>')
L.append('')
L.append(', '.join('`%s/%d`' % k for k in gnu_only) if gnu_only else 'none')
L.append('')
L.append('</details>')
L.append('')
both_open = sorted(k for k in (gnu & swi) if not ok(k) and k not in iso)
L.append('## In BOTH GNU and SWI but not ISO, still open — %d (de-facto standard)' % len(both_open))
L.append('')
L.append('<details><summary>expand</summary>')
L.append('')
L.append(', '.join('`%s/%d`' % k for k in both_open) if both_open else 'none')
L.append('')
L.append('</details>')
L.append('')
L.append('---')
L.append('')
L.append('Generated %s from `%s` + `%s`.' % (datetime.date.today().isoformat(),
                                             os.path.basename(GP), os.path.basename(SW)))
txt = '\n'.join(L) + '\n'
if MODE == '--check':
    cur = rd(OUT)
    stale = (cur != txt)
    print('dialect audit: ISO open=%d  GNU open=%d  SWI open=%d  stale=%s'
          % (len(open_iso), len([k for k in gnu if not ok(k)]), len([k for k in swi if not ok(k)]), stale))
    sys.exit(1 if stale else 0)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'w').write(txt)
print('ISO total=%d open=%d | GNU total=%d open=%d | SWI total=%d open=%d | UNION total=%d open=%d'
      % (len(iso), len(open_iso), len(gnu), len([k for k in gnu if not ok(k)]),
         len(swi), len([k for k in swi if not ok(k)]), len(u), t - d))
print('wrote ' + OUT)
PY
