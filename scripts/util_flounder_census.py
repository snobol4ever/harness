#!/usr/bin/env python3
# util_flounder_census.py -- WHICH ROWS ARE BEING PASSED AROUND, AND WHICH CLAIMS SIT IDLE IN A HAND (ceo, 2026-09-04, on
# Lon's order: "Check if any task is being passed around and floundering. If you find then those must be delegated to HQ
# since they are Opus not Sonnet. And if any HQ is floundering CEO ... must take the actual task item and work it themselves.")
# Reads QUEUE.tsv, every tasks/*.task.md LEDGER and claims/*.claim; never writes. Per open row: releases (a holder took it
# and gave it back unworked), reopens, parks, distinct holders, age, hours since the baton was last touched, the live claim.
# rc=0 nothing floundering by the thresholds below / rc=1 floundering rows or idle claims NAMED / rc=2 postoffice unreadable.
#   --top N (default 28) · --releases R (default 5: a row released R+ times with no HQ working it is floundering)
#   --idle-hq H (default 12: an HQ claim taken H+ hours ago with the baton untouched 3h+ is idle in hand)
import argparse, sys
ap=argparse.ArgumentParser(); ap.add_argument('--top',type=int,default=28); ap.add_argument('--releases',type=int,default=5); ap.add_argument('--idle-hq',type=float,default=12); A=ap.parse_args()
import os, re, glob, time, datetime, collections
PO='/home/resources/postoffice'; now=time.time()
if not os.path.isdir(PO+'/tasks'): print('REFUSE(2): no postoffice at '+PO); sys.exit(2)
rows={}
for ln in open(PO+'/QUEUE.tsv','rb').read().decode('utf-8','replace').split('\n'):
    if ln.startswith('#') or ln.count('\t')<3: continue
    f=ln.split('\t'); rows[f[1]]={'rank':f[0],'owner':f[2],'state':f[3]}
claims={}
for c in glob.glob(PO+'/claims/*.claim'):
    t=os.path.basename(c)[:-6]; L=open(c,errors='replace').read().split('\n')
    claims[t]={'holder':L[0].strip(),'last':(L[-1] or L[-2] if len(L)>1 else '').strip()[:30],'age_h':(now-os.path.getmtime(c))/3600,'taken_h':(now-os.path.getctime(c))/3600}
date_re=re.compile(r'(20\d\d-\d\d-\d\d)')
out=[]
for t,r in rows.items():
    st=r['state']
    if st.startswith(('DONE','RETIRED','SUPERSEDED')): continue
    p=f'{PO}/tasks/{t}.task.md'
    if not os.path.exists(p): continue
    s=open(p,errors='replace').read()
    led=s.split('## LEDGER',1)[1] if '## LEDGER' in s else s
    releases=len(re.findall(r'\*\*RELEASED\*\*',led))
    reopens=len(re.findall(r'REOPEN',led,re.I))
    parks=len(re.findall(r'STATE -> (PARKED|BLOCKED|GRANT)',led))
    authors=set(re.findall(r'\[(seat\d\d|hq_[A-Z]|ceo)·',led))|set(re.findall(r'RELEASED\*\* by (seat\d\d|hq_[A-Z]|ceo)',led))|set(re.findall(r'(?:ASSIGNED|CLAIMED):(seat\d\d|hq_[A-Z])',st))
    authors.discard('ceo')
    dates=sorted(set(date_re.findall(s)))
    first=dates[0] if dates else None
    age=(now-datetime.datetime.strptime(first,'%Y-%m-%d').timestamp())/86400 if first else 0
    last_h=(now-os.path.getmtime(p))/3600
    cl=claims.get(t)
    score=releases*3+reopens*3+max(0,len(authors)-1)*2+parks+(2 if age>3 else 0)+(2 if cl and cl['taken_h']>6 and last_h>3 else 0)
    out.append((score,t,r,releases,reopens,parks,sorted(authors),age,last_h,cl))
out.sort(key=lambda x:-x[0])
FLOUNDER=[]
print('score topic | rank state owner | releases reopens parks | holders | age_d last_activity_h | claim')
for score,t,r,rel,reo,pk,au,age,lh,cl in out[:A.top]:
    c=f"{cl['holder']} taken {cl['taken_h']:.1f}h [{cl['last'][:18]}]" if cl else '-'
    print(f"{score:2d} {t[:66]:66s} | {r['rank']} {r['state'][:28]:28s} {r['owner']:6s} | {rel:2d} {reo:2d} {pk:2d} | {','.join(au)[:44]:44s} | {age:4.1f} {lh:5.1f} | {c}")
IDLE=[]
print('\n== HQ-held claims idle (claim taken >%gh, baton untouched >3h)' % A.idle_hq)
for score,t,r,rel,reo,pk,au,age,lh,cl in out:
    if cl and cl['holder'].startswith('hq_') and cl['taken_h']>A.idle_hq and lh>3: IDLE.append(t); print(f"  {cl['holder']} {t[:70]} taken {cl['taken_h']:.1f}h ago, baton last touched {lh:.1f}h ago, state {r['state'][:24]}")
print('\n== seat-held claims idle (>3h, baton untouched >2h)')
for score,t,r,rel,reo,pk,au,age,lh,cl in out:
    if cl and cl['holder'].startswith('seat') and cl['taken_h']>3 and lh>2: print(f"  {cl['holder']} {t[:70]} taken {cl['taken_h']:.1f}h ago, baton {lh:.1f}h, state {r['state'][:24]}")

for score,t,r,rel,reo,pk,au,age,lh,cl in out:
    if rel>=A.releases and not (cl and cl['holder'].startswith(('hq_','ceo'))): FLOUNDER.append(t)
print('\nFLOUNDER_CENSUS rows_open=%d floundering(releases>=%d, no HQ/ceo working it)=%d idle_hq_claims(>%gh)=%d' % (len(out), A.releases, len(FLOUNDER), A.idle_hq, len(IDLE)))
for t in FLOUNDER: print('  FLOUNDERING ' + t)
sys.exit(1 if (FLOUNDER or IDLE) else 0)
