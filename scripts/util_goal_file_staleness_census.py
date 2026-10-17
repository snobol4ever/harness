#!/usr/bin/env python3
# util_goal_file_staleness_census.py -- grade every .github/GOAL-*.md RUNG/STEP against LIVE source.
#
# Lon's test (2026-08-28, row goal-files-major-consolidation): "Check each RUNG and STEPS and see if it is
# so out of date that it references source functions or variables that no longer exist." This produces that
# number, so nobody has to quote one they did not measure.
#
# METHOD: index every identifier in SCRIP/src/** and harness/scripts/**, then score each GOAL file's BACKTICKED
# code-shaped identifiers (contain _, or ALL-CAPS, or camelCase) as LIVE or GONE.
#
# VALIDATED BEFORE USE, and it discriminates WITHIN a single file: on GOAL-CHUNKS.md it flags the retired
# E_CHOICE/E_CUT/E_SUSPEND vocabulary while leaving SM_ACOMP/SM_PUSH_EXPR/EXPR_t alone as live.
#
# TWO LIMITS -- read `gone` BESIDE `syms`, never the percentage alone:
#   (1) it conflates "our symbol was retired" with "never was our symbol" (a .NET exception name scores GONE,
#       which is the right conclusion about the doc but is not a rename);
#   (2) a file citing 3 symbols yields 100% on a sample of 3, so small files ride high in a %-sort.
# And ONE INVERSION THE NUMBER CANNOT SEE: a REORG doc legitimately names the homes it retired --
# GOAL-SRC-REORG.md tops the retired-home count BECAUSE it documents that move. Do not grade it stale for
# naming what it killed. That is why this census feeds a HUMAN pass and never an automated deletion.
#
# Usage: python3 ../harness/scripts/util_goal_file_staleness_census.py     (root from S4E_HOME, else derived from $0)
import re, pathlib, sys, collections, os
_here = pathlib.Path(__file__).resolve().parent          # harness/scripts
ROOT = pathlib.Path(os.environ.get('S4E_HOME', str(_here.parent.parent)))
GH=ROOT/'.github'
# ---- 1. index every identifier that EXISTS in the live tree ----------------
ident=re.compile(r'[A-Za-z_][A-Za-z0-9_]{2,}')
live=set()
for base,exts in ((ROOT/'SCRIP'/'src',{'.c','.h','.cpp','.y','.l','.inc','.S','.s'}),
                  (ROOT/'SCRIP'/'scripts',{'.sh','.py'}),
                  (ROOT/'SCRIP',{'.mk',''})):
    for p in base.rglob('*'):
        if not p.is_file() or p.suffix not in exts: continue
        try: live.update(ident.findall(p.read_text(errors='replace')))
        except Exception: pass
for p in [ROOT/'SCRIP'/'Makefile']:
    if p.is_file(): live.update(ident.findall(p.read_text(errors='replace')))
# live file/dir names too
livepaths={str(p.relative_to(ROOT)) for p in ROOT.rglob('*') if 'ial' not in '' }
sys.stderr.write(f"live identifiers indexed: {len(live)}\n")

# ---- 2. per GOAL file: which cited code symbols are GONE? ------------------
EXCL={'GOAL-CEO.md','GOAL-HQ-BEAUTIFY.md','GOAL-HQ-COMPLETE.md','GOAL-HQ-PERFORM.md','GOAL-SCRIP-HQ.md'}
code=re.compile(r'`([A-Za-z_][A-Za-z0-9_]{3,})(?:\(\))?`')      # backticked identifier
rung=re.compile(r'^\s*(?:RUNG|STEP|R\d+|S\d+)\b', re.M|re.I)
rows=[]
for f in sorted(GH.glob('GOAL-*.md')):
    t=f.read_text(errors='replace')
    syms=set(code.findall(t))
    # ignore prose words that merely look like identifiers
    syms={s for s in syms if ('_' in s or s.isupper() or re.search(r'[a-z][A-Z]',s))}
    gone=sorted(s for s in syms if s not in live)
    nr=len(rung.findall(t))
    pct=(100.0*len(gone)/len(syms)) if syms else 0.0
    rows.append((f.name, len(t.splitlines()), nr, len(syms), len(gone), pct, gone[:4],
                 f.name in EXCL, f.name.endswith('-100.md')))
rows.sort(key=lambda r:(-r[5],-r[4]))
print(f"{'GOAL file':44s} {'lines':>5s} {'rung':>4s} {'syms':>5s} {'gone':>4s} {'%gone':>6s}  role")
print('-'*104)
for n,l,nr,ns,ng,pct,ex,isorg,is100 in rows:
    role='ORG(excluded)' if isorg else ('x100(target)' if is100 else '')
    print(f"{n:44s} {l:5d} {nr:4d} {ns:5d} {ng:4d} {pct:5.1f}%  {role}")
tot=[r for r in rows if not r[7] and not r[8]]
print(f"\nconsolidation INPUTS (excl 5 org + 7 x100): {len(tot)}")
print(f"  inputs with >=50% cited symbols GONE: {sum(1 for r in tot if r[5]>=50)}")
print(f"  inputs with >=25% gone:               {sum(1 for r in tot if r[5]>=25)}")
print(f"  inputs citing ZERO code symbols:      {sum(1 for r in tot if r[3]==0)}")
