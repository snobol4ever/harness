import re, sys, subprocess, os, tempfile
RELOAD = re.compile(r'\br8\s*,\s*qword ptr \[rip \+ rtccb\+40\]')
R8ANY  = re.compile(r'\br8[bwd]?\b')
DEREF  = re.compile(r'\[[^\]]*\br8[bwd]?\b[^\]]*\]')
WRITE  = re.compile(r'^\s*(mov|movq|lea|xor|pop|movabs)\s+r8[bwd]?\s*,')
XORSELF= re.compile(r'^\s*xor\s+r8[bwd]?\s*,\s*r8[bwd]?\s*$')
FLOW   = re.compile(r'^\s*(jmp|ret|call)\b')
LABEL  = re.compile(r'^[A-Za-z_.$][\w.$]*:')
def classify(lines, i, limit=60, through=False):
    crossed = False
    for j in range(i+1, min(len(lines), i+1+limit)):
        raw = lines[j]
        s = raw.split('#')[0].rstrip()
        if not s.strip(): continue
        if LABEL.match(s):
            if not through: return ('UNRESOLVED', j, 'label reached before any r8 use: ' + s.strip()[:60])
            crossed = True
        if not R8ANY.search(s):
            if FLOW.match(s):
                if s.strip().startswith('call'): continue
                return ('UNRESOLVED', j, 'control flow before any r8 use: ' + s.strip()[:60])
            continue
        sfx = '_XBLOCK' if crossed else ''
        if DEREF.search(s):  return ('POINTER_DEREF'+sfx, j, s.strip()[:80])
        if XORSELF.match(s): return ('OVERWRITTEN'+sfx, j, s.strip()[:80])
        if WRITE.match(s):   return ('OVERWRITTEN'+sfx, j, s.strip()[:80])
        return ('INTEGER_USE'+sfx, j, s.strip()[:80])
    return ('UNRESOLVED', -1, 'no r8 use within %d lines' % limit)
def census(path, label, through=False):
    lines = open(path, errors='replace').read().split('\n')
    out = []
    for i, l in enumerate(lines):
        if RELOAD.search(l):
            k, j, ev = classify(lines, i, through=through)
            out.append((k, label, i+1, j+1 if j>0 else -1, ev))
    return out
def main():
    args = sys.argv[1:]
    through = '--through-labels' in args
    args = [a for a in args if a != '--through-labels']
    if args and args[0] == '--selftest':
        fix = ["  mov r8,  qword ptr [rip + rtccb+40]", "  mov rax, qword ptr [r8 + 8]",
               "  mov r8,  qword ptr [rip + rtccb+40]", "  mov r8, rcx",
               "  mov r8,  qword ptr [rip + rtccb+40]", "  add r8, 16",
               "  mov r8,  qword ptr [rip + rtccb+40]", "  jmp .Lsomewhere"]
        with tempfile.NamedTemporaryFile('w', suffix='.s', delete=False) as f:
            f.write('\n'.join(fix)); p = f.name
        got = [r[0] for r in census(p, 'selftest')]; os.unlink(p)
        want = ['POINTER_DEREF','OVERWRITTEN','INTEGER_USE','UNRESOLVED']
        print("SELFTEST want=%s got=%s" % (want, got))
        if got != want:
            print("⛔ SELFTEST FAILED: the classifier does not answer a hand-built window correctly, so no verdict it gives over the corpus can be believed.")
            return 2
        print("✅ SELFTEST: all four classes answered correctly on a hand-built window")
        return 0
    rows = []
    for a in args:
        if a.endswith('.s'):
            rows += census(a, os.path.basename(a), through); continue
        with tempfile.NamedTemporaryFile('w', suffix='.s', delete=False) as f: sp = f.name
        r = subprocess.run(['./scrip','--compile',a], capture_output=True, text=True, timeout=120)
        if r.returncode != 0 or not r.stdout.strip():
            print("  SKIP %s (--compile produced nothing)" % os.path.basename(a)); os.unlink(sp); continue
        open(sp,'w').write(r.stdout)
        rows += census(sp, os.path.basename(a), through); os.unlink(sp)
    counts = {}
    for k,_,_,_,_ in rows: counts[k] = counts.get(k,0)+1
    for k in ('POINTER_DEREF','POINTER_DEREF_XBLOCK','INTEGER_USE','INTEGER_USE_XBLOCK','OVERWRITTEN','OVERWRITTEN_XBLOCK','UNRESOLVED'):
        for r in [x for x in rows if x[0]==k]:
            print("CENSUS anchor-use MEMBER %-14s %s reload@%d use@%d  %s" % (r[0], r[1], r[2], r[3], r[4]))
    tot = len(rows)
    print("CENSUS anchor-use EXAMINED %d reload site(s): POINTER_DEREF=%d (+%d across a block boundary) INTEGER_USE=%d (+%d) OVERWRITTEN=%d (+%d) UNRESOLVED=%d"
          % (tot, counts.get('POINTER_DEREF',0), counts.get('POINTER_DEREF_XBLOCK',0), counts.get('INTEGER_USE',0),
             counts.get('INTEGER_USE_XBLOCK',0), counts.get('OVERWRITTEN',0), counts.get('OVERWRITTEN_XBLOCK',0), counts.get('UNRESOLVED',0)))
    if not through:
        print("REACH: this pass STOPS at the first label, because a label is a jump target and r8's value there is not this reload's. Re-run with --through-labels to walk past it; those members are reported with an _XBLOCK suffix and are WEAKER evidence, not equal evidence.")
    if tot == 0:
        print("⛔ REFUSE: zero reload sites examined -- a census that finds nothing grades everything green."); return 2
    print("PREDICATE: a member is a LOST VALUE only if its reloaded r8 is DEREFERENCED before being overwritten. INTEGER_USE and OVERWRITTEN are NOT hazards; an anchor read as an integer does not care that its bits name vacated ground.")
    return 0
sys.exit(main())
