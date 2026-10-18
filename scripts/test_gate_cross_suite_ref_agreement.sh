#!/usr/bin/env bash
# test_gate_cross_suite_ref_agreement.sh -- TWO SUITES MUST NOT HOLD CONTRADICTORY REFS FOR A BYTE-IDENTICAL
# PROGRAM. When they do, at least one ref is wrong, and nothing in the tree says which -- so a board built on
# the wrong one reports a red that is CORRECT OUTPUT FAILING A BAD REF.
#
# ⛔ WHY THIS EXISTS, and it is a measured cost, not a hypothetical (hq_B 2026-09-03, row ICN4, ceo CEO-177):
# `procedure_every_scan_replace_5` in ALL.ref said Icon's x[-3+:6] FAILS; `rung36_jcon_lists` in
# rung36_all.ref said it yields `[4] 3 4 5 6`. THE SOURCES WERE BYTE-IDENTICAL. icont agrees with the second.
# ALL.ref was wrong, so the rungs board's two reds were correct SCRIP output failing a bad ref -- and I
# "cured" the compiler to match the bad ref, landing a real regression and a FALSE GREEN at 380/381 that five
# green arms and a ceo audit all missed, because not one of them asked the ORACLE.
# ⭐ A ref is evidence about a PAST ORACLE RUN, not about the oracle. This gate cannot tell which ref is right
# -- only an oracle run can -- but it can prove that a disagreement EXISTS, which is the cheap half and the
# half that was available to me for free the whole time. It converts "somebody eventually notices" into a red.
#
# METHOD: corpus/tests/<lang>/ALL.csv carries a durable `origin` of the form <family>__<entry>. Where that
# family exists as a sibling suite (<family>.icn + <family>.ref), the same program is present twice. For every
# such pair: if the SOURCES are byte-identical and the REFS differ, that is a contradiction -- reported by name,
# with the first differing line of each, so the reader can take it to the oracle immediately.
# ⛔ Sources that DIFFER are silently fine: an entry legitimately edited on conversion is a different program,
# and flagging it would make this gate noise. Only byte-identical sources are evidence about refs.
# EXIT 0 no contradictions; 1 at least one (names them); 2 REFUSED (cannot measure -- never skip-as-success).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
CORPUS="${CORPUS:-$S4E/corpus/tests}"
[ -d "$CORPUS" ] || { echo "⛔ GATE REFUSED (rc=2): cannot see $CORPUS -- nothing was checked" >&2; exit 2; }
python3 - "$CORPUS" <<'PY'
import io,os,re,sys
root=sys.argv[1]
mark=re.compile(r'^#-{5,} \d+ (\S+)\s*$')
def sections(path):
    out={}
    try: lines=io.open(path,encoding='utf-8',errors='replace').read().split('\n')
    except OSError: return out
    cur=None; buf=[]
    for l in lines:
        m=mark.match(l)
        if m:
            if cur is not None: out[cur]='\n'.join(buf)
            cur=m.group(1); buf=[]
        elif cur is not None: buf.append(l)
    if cur is not None: out[cur]='\n'.join(buf)
    return out
langs=sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root,d)))
checked=0; pairs=0; bad=[]
for lang in langs:
    d=os.path.join(root,lang); csv=os.path.join(d,'ALL.csv')
    icn=[f for f in os.listdir(d) if f.startswith('ALL.') and f not in ('ALL.csv','ALL.ref')]
    if not os.path.exists(csv) or not os.path.exists(os.path.join(d,'ALL.ref')): continue
    mref=sections(os.path.join(d,'ALL.ref'))
    # PICK THE RUNGS SOURCE DETERMINISTICALLY. A first cut took the first ALL.* off os.listdir() and got
    # ALL.trace or ALL.in on some runs -- which parses, yields a small bogus section set, and silently drops
    # most pairs (10 seen where 76 exist). An unordered listdir is not a selection rule. Choose the candidate
    # whose section NAMES overlap ALL.ref's most: the real source is the file that shares the ref's entries.
    src_rungs=None; best=0
    for f in sorted(icn):
        fp=os.path.join(d,f)
        if not os.path.isfile(fp): continue
        ov=len(set(sections(fp)) & set(mref))
        if ov>best: best=ov; src_rungs=fp
    if not src_rungs: continue
    msrc=sections(src_rungs)
    ext=os.path.splitext(src_rungs)[1]
    rows=io.open(csv,encoding='utf-8',errors='replace').read().split('\n')
    if not rows: continue
    hdr=rows[0].split(','); 
    try: ie=hdr.index('entry'); io_=hdr.index('origin')
    except ValueError: continue
    cache={}
    for r in rows[1:]:
        c=r.split(',')
        if len(c)<=max(ie,io_): continue
        entry=c[ie]; origin=c[io_]
        if '__' not in origin: continue
        fam,oentry=origin.split('__',1)
        fsrc=os.path.join(d,fam+ext); fref=os.path.join(d,fam+'.ref')
        if not (os.path.exists(fsrc) and os.path.exists(fref)): continue
        if fam not in cache: cache[fam]=(sections(fsrc),sections(fref))
        ssrc,sref=cache[fam]
        if entry not in msrc or entry not in mref: continue
        if oentry not in ssrc or oentry not in sref: continue
        checked+=1
        if msrc[entry]!=ssrc[oentry]: continue      # different program; refs may legitimately differ
        pairs+=1
        # ⭐ NORMALISE THE PROGRAM'S OWN NAME BEFORE COMPARING. A program that writes &progname prints the
        # entry name it was converted under, and the two suites deliberately name the same program
        # differently (procedure_every_alt_replace_4 vs rung36_jcon_kwds). That is a RENAME, not a ref
        # disagreement, and reporting it would make this gate noise on its very first run -- which is how a
        # gate gets ignored. Only differences that survive the rename are evidence about the oracle.
        ma=mref[entry].replace(entry,'<PROGNAME>'); sa=sref[oentry].replace(oentry,'<PROGNAME>')
        if ma!=sa:
            a=ma.split('\n'); b=sa.split('\n')
            first=next((f"{x!r}  vs  {y!r}" for x,y in zip(a,b) if x!=y), "(one ref is a prefix of the other)")
            bad.append((lang,entry,os.path.basename(src_rungs),oentry,fam,first))
print(f"cross-suite ref agreement: {pairs} byte-identical program pair(s) compared "
      f"({checked} origin-linked entries seen) across {len(langs)} language dir(s)")
if bad:
    sys.stderr.write("⛔ GATE FAIL (rc=1): CONTRADICTORY REFS for byte-identical sources -- at least one ref is WRONG:\n")
    for lang,entry,mf,oentry,fam,first in bad:
        sys.stderr.write(f"    [{lang}] {mf}:{entry}  vs  {fam}.ref:{oentry}\n        first difference: {first}\n")
    sys.stderr.write("  ⛔ This gate cannot say WHICH ref is right -- run the ORACLE on the program and re-cut the loser.\n")
    sys.stderr.write("     Do NOT change the compiler to satisfy a ref until the oracle has spoken (row ICN4, 2026-09-03).\n")
    sys.exit(1)
if pairs==0:
    sys.stderr.write("⛔ GATE REFUSED (rc=2): 0 byte-identical pairs found -- a green here would be an empty claim\n"); sys.exit(2)
print("✅ GATE OK: every byte-identical program shared between two suites carries the SAME ref")
PY
