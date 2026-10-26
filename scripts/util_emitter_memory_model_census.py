#!/usr/bin/env python3
"""util_emitter_memory_model_census.py [--at-most N] [--list] -- THE MEMORY MODEL IS CALCULATED IN THE PLANNER AND NOWHERE ELSE (ceo CEO-1988).

Lon 2026-10-26, in-chat to the ceo, verbatim: "Oh, big dummy, you've been lying again. So get the memory-model calculations moved out of EMITTER and
SOLELY into PLANNER."  The deletion of the 27 named placement predicates (util_placement_predicates_census.py, alive=0/27) was reported as
"placement decided once" while the emitter went on calculating the memory model; this census counts what that one did not.

Read from SCRIP's source, no build, no run:
  (A) CALLS from src/emitter/ and src/templates/ into a function DEFINED in src/planner/, the frame layout (src/planner/frame_layout.c) or the
      zeta-depth analysis (src/planner/zeta_depth.c) -- the
      emitter asking the memory model a question instead of reading the planner's record; a declaration (`extern ... name(...);`) is not a call;
  (B) DEFINITIONS in src/emitter/ of a memory-model function (a name in the fc_ frame_ zd_ zls_ xop_ act_ planner_ families) -- a calculation that
      lives in the emitter;
  (C) whole-graph index reads in src/emitter/ (`g_emit_cfg->all` and `->all[`), REPORTED, not in the bar: the emitter emits a chain and walks it,
      and which of these reads computes a memory fact is the landing's to show.
The bar is A + B. --at-most N exits 1 when A + B > N (the ratchet each landing owes: it may only fall); rc 2 when the tree cannot be read.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIP = os.path.normpath(os.path.join(HERE, '..', '..', 'SCRIP'))
FAMILIES = ('fc_', 'frame_', 'zd_', 'zls_', 'xop_', 'act_', 'planner_')
ALLOW = set()
DEF = re.compile(r'^\s*(?:extern\s+"C"\s+)?(?:static\s+)?(?:inline\s+)?(?:const\s+)?[A-Za-z_][\w\s\*:<>,]*?[\s\*]([A-Za-z_]\w*)\s*\(([^;{}]*)\)\s*(?:const\s*)?\{')


def files(root, exts):
    out = []
    for d, _, fs in os.walk(root):
        for f in sorted(fs):
            if f.endswith(exts):
                out.append(os.path.join(d, f))
    return sorted(out)


def defined(paths):
    names = set()
    for p in paths:
        for line in open(p, encoding='utf-8', errors='replace'):
            m = DEF.match(line)
            if m and m.group(1) not in ('if', 'for', 'while', 'switch', 'return', 'sizeof'):
                names.add(m.group(1))
    return names


def main(argv):
    at_most = None
    lst = '--list' in argv
    if '--at-most' in argv:
        try:
            at_most = int(argv[argv.index('--at-most') + 1])
        except (IndexError, ValueError):
            print('REFUSED(2): --at-most needs a number', file=sys.stderr)
            return 2
    if not os.path.isdir(os.path.join(SCRIP, 'src', 'emitter')):
        print('REFUSED(2): no SCRIP tree at %s' % SCRIP, file=sys.stderr)
        return 2
    mm_src = files(os.path.join(SCRIP, 'src', 'planner'), ('.c', '.cpp', '.h', '.inc')) + [os.path.join(SCRIP, 'src', 'ir', f) for f in ('frame_layout.c', 'zeta_depth.c') if os.path.exists(os.path.join(SCRIP, 'src', 'ir', f))]
    mm = defined([p for p in mm_src if os.path.exists(p)]) - ALLOW
    emitter = files(os.path.join(SCRIP, 'src', 'emitter'), ('.c', '.cpp', '.h', '.inc'))
    templates = files(os.path.join(SCRIP, 'src', 'templates'), ('.c', '.cpp', '.h', '.inc'))
    call_re = re.compile(r'(?<![\w.>])(' + '|'.join(sorted(map(re.escape, mm), key=len, reverse=True)) + r')\s*\(') if mm else None
    a_by = {}
    a_files = {}
    for p in emitter + templates:
        rel = os.path.relpath(p, SCRIP)
        for line in open(p, encoding='utf-8', errors='replace'):
            if not call_re:
                break
            line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
            for stmt in line.split(';'):
                if re.search(r'\bextern\b', stmt):
                    continue
                for m in call_re.finditer(stmt):
                    if DEF.match(stmt + '{') and stmt.strip().endswith(')'):
                        continue
                    a_by[m.group(1)] = a_by.get(m.group(1), 0) + 1
                    a_files[rel] = a_files.get(rel, 0) + 1
    b_names = sorted(n for n in defined(emitter) if n.startswith(FAMILIES))
    c = 0
    for p in emitter:
        txt = open(p, encoding='utf-8', errors='replace').read()
        c += txt.count('g_emit_cfg->all') + len(re.findall(r'->all\[', txt))
    a = sum(a_by.values())
    b = len(b_names)
    print('EMITTER_MEMORY_MODEL A_calls=%d (into %d planner/layout functions, from %d files) B_emitter_defs=%d C_graph_reads=%d bar=A+B=%d%s' % (
        a, len(a_by), len(a_files), b, c, a + b, '' if at_most is None else ' at-most=%d' % at_most))
    for f, n in sorted(a_files.items(), key=lambda kv: -kv[1]):
        print('  A %-44s %5d' % (f, n))
    if lst:
        for n, k in sorted(a_by.items(), key=lambda kv: -kv[1]):
            print('  A-fn %-44s %5d' % (n, k))
        for n in b_names:
            print('  B-def %s' % n)
    if at_most is not None and a + b > at_most:
        print('⛔ RED: A+B=%d is over the ratchet %d -- the emitter calculates the memory model (CEO-1988)' % (a + b, at_most))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
