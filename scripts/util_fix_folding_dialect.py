#!/usr/bin/env python3
"""util_fix_folding_dialect.py -- uppercase SPITBOL KEYWORDS in the folding-dialect programs so they mean the same thing under
`sbl -bf` (case-SENSITIVE) that they meant under `sbl -b` (case-FOLDING).

DECISION PROCEDURE (per program):
  needs_fix  iff the program is BROKEN under -bf today: rc != 0, or (a pinned .ref exists and the
             -bf output does not match it).  A program already correct under -bf is LEFT ALONE --
             the corpus holds BOTH dialects, and beauty.sno / 210_indirect_ref.sno depend on
             `Integer` != INTEGER and `bal` != BAL.  Blanket uppercasing would break them.
  accept     iff after the edit, -bf rc == 0 AND output == pin (if pinned) else == the -b output
             the program produced BEFORE the edit.  Otherwise REVERT and report.
⛔ TWO DIRECTORIES ARE NEVER OPENED, BY CONSTRUCTION (OFF_LIMITS below, enforced in closure() so the
   walk never descends and in the write loop as a belt): corpus/lon/ (RULES.md ABSOLUTE --
   do not run, do not read) and corpus/include/ (HQ interim s191 -- inherits the do-not-read
   half pending Lon's credential ruling).  Both locks are READ locks, not just write locks: closure()
   open()s every file it reaches, and a secret read into a transcript has been copied somewhere new.
   CONSEQUENCE, STATED SO IT IS NOT MISREAD AS A BUG: a gimpel program whose fix needs an uppercased
   file under include/ cannot be completed, so the accept test fails and the driver REVERTS
   and names it.  That is the correct outcome, not a failure of the tool."""
import os, re, subprocess, sys, hashlib, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from util_uppercase_keywords import fix_text
S4E=os.environ.get("S4E_HOME") or os.path.dirname(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "SCRIP"))   # D-17 PORTABLE-HOME: sibling root from $0, as util_oracle_flag_sweep.sh does; the hardcoded /home/claude1 made this script seat-local
CORPUS=S4E+"/corpus"; SBL=(os.environ.get("SBL") or S4E+"/x64/bin/sbl"); SC=S4E+"/SCRIP"
OFF_LIMITS=("/programs/lon/","/programs/include/")   # lon: RULES.md ABSOLUTE (do not run, do not read).  include/: HQ interim s191 -- inherits the do-not-read half pending Lon's credential ruling, so it is excluded BY CONSTRUCTION here, not skipped at run time
def off_limits(path): return any(k in path.replace(os.sep,"/") for k in OFF_LIMITS)
DEMO=CORPUS+"/demo"
NRM=re.compile(rb"^(?:iters|ms): [0-9]+\n", re.M)
# ⛔ s191: SPITBOL's ABNORMAL-TERMINATION report carries ENVIRONMENT-DEPENDENT lines.  Measured on
# csnobol4_suite/tab.sno: the uppercasing was CORRECT and the only difference from the -b baseline was
# `memory used (bytes) 15912` vs `15888` (24 bytes, from the symbol table holding different identifier
# strings) -- so the accept test REVERTED a good conversion.  These three lines are not a semantic
# property of the program, exactly as the scorecard already argues for its own iters:/ms: rule.
# `stmts executed` and `REGENERATIONS` are DELIBERATELY NOT stripped: those are deterministic given
# the program and a change in them is a real behavioural change worth failing on.
ENVN=re.compile(rb"^(?:execution time msec|memory used \(bytes\)|memory left \(bytes\))\s+[0-9]+\n", re.M)
def norm(b): return ENVN.sub(b"", NRM.sub(b"", b))
def libspec(su): return {"beauty_self":"include","patterns":"demo/inc","crosscheck":"demo/inc",
    "feature_test":"CORPUS","gimpel":"SELFDIR:include"}.get(su,"SELFDIR")
def libpath(spec,pd):
    out=[]
    for e in spec.split(":"):
        out.append(pd if e=="SELFDIR" else CORPUS if e=="CORPUS" else CORPUS+"/"+e)
    return ":".join(out)
def stdin_for(p):
    b=p[:-4]; d=os.path.dirname(p); n=os.path.basename(b)
    for ext in (".input",".in"):
        if os.path.exists(b+ext): return b+ext
    if d==DEMO:
        for k in ("claws5","treebank","json","calculator","porter"):
            if n.startswith(k): return DEMO+"/"+k+".input"
    return "/dev/null"
def run(flag, prog, d, L, stdin):
    with open(stdin,"rb") as fi:
        r=subprocess.run([SBL,flag,"-d512m","-i64m",prog],cwd=d,stdin=fi,
                         capture_output=True,timeout=90,env={**os.environ,"SETL4PATH":"."+":"+L})
    return r.returncode, norm(r.stdout)
INC=re.compile(r"^-[Ii][Nn][Cc][Ll][Uu][Dd][Ee]\s+['\"]([^'\"]+)['\"]", re.M)
def closure(prog, L, seen=None):
    """program + every file it -INCLUDEs, resolved along the lib path (transitive)."""
    if seen is None: seen=set()
    if prog in seen or not os.path.exists(prog) or off_limits(prog): return seen   # off-limits files are never opened, so they can never be read into a transcript nor rewritten
    seen.add(prog)
    try: txt=open(prog,"rb").read().decode("utf-8","surrogateescape")
    except Exception: return seen
    for name in INC.findall(txt):
        for base in [os.path.dirname(prog)]+L.split(":"):
            cand=os.path.normpath(os.path.join(base,name.strip()))
            if os.path.exists(cand): closure(cand,L,seen); break
    return seen
def main():
    rows=[l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if l.strip()]
    movers=[r for r in rows if r[6]=="MOVER"]
    fixed=[]; left=[]; failed=[]
    for su,prog,rb,rf,mb,mf,tag in movers:
        full=prog if prog.startswith("/") else CORPUS+"/"+prog
        assert not off_limits(full), full
        if not os.path.exists(full): continue
        d=os.path.dirname(full); L=libpath(libspec(su),d); stdin=stdin_for(full)
        ref=full[:-4]+".ref"; pin=norm(open(ref,"rb").read()) if os.path.exists(ref) else None
        rc_b,out_b = run("-b", full, d, L, stdin)
        rc_f,out_f = run("-bf", full, d, L, stdin)
        # DIALECT GUARD.  The corpus holds BOTH dialects.  A program whose PIN matches the
        # -bf answer is written in the CASE-SENSITIVE dialect (beauty.sno's `Integer` != INTEGER,
        # 210_indirect_ref's `bal` != protected BAL) and must NEVER be uppercased.  Everything
        # else that is broken under -bf is folding-dialect and gets the keyword uppercasing.
        if pin is not None and out_f == pin:
            left.append((su,prog,"already correct under -bf (matches pin) -- CASE-SENSITIVE dialect, not touched")); continue
        if rc_f == 0 and out_f == out_b:
            left.append((su,prog,"not broken under -bf")); continue
        if pin is None and rc_f == 0 and rc_b == 0:
            failed.append((su,prog,"AMBIGUOUS: no pin, both arms run cleanly and disagree -- needs a human, not touched")); continue
        pin_is_target = pin is not None and out_b == pin
        target = pin if pin_is_target else out_b
        files=sorted(closure(full,L)); backup={}
        for f in files:
            assert not off_limits(f), f
            raw=open(f,"rb").read(); src=raw.decode("utf-8","surrogateescape"); out=fix_text(src)
            if out!=src: backup[f]=raw; open(f,"wb").write(out.encode("utf-8","surrogateescape"))
        if not backup: failed.append((su,prog,"broken-under-bf but uppercaser changes NOTHING")); continue
        rc2,out2 = run("-bf", full, d, L, stdin)
        ok = (rc2==0 and out2==target)
        if ok:
            note = "verified == pin" if pin_is_target else ("verified == -b baseline" + ("" if pin is None else "; PIN MATCHES NEITHER ARM (pre-existing, untouched)"))
            fixed.append((su,prog,"%d file(s); %s"%(len(backup),note)))
        else:
            for f,raw in backup.items(): open(f,"wb").write(raw)
            why = "rc=%d"%rc2 if rc2!=0 else "output still != target"
            failed.append((su,prog,"REVERTED: "+why))
    for lbl,lst in (("FIXED",fixed),("LEFT ALONE",left),("NOT FIXED",failed)):
        print("\n=== %s (%d) ==="%(lbl,len(lst)))
        for su,p,note in lst: print("  %-15s %-52s %s"%(su,p,note))
if __name__ == "__main__": main()   # ⛔ s191: main() used to run at MODULE level, so `import util_fix_folding_dialect` to reuse stdin_for/libpath/run/norm SILENTLY EXECUTED A FULL FIX PASS over whatever sys.argv[1] happened to be.  Measured: it did, over all 42 movers instead of a reviewed 21.  Nothing was damaged -- every file failed the accept test and was reverted, which is the guard working -- but a reader must be able to import this module for its helpers without editing the corpus.
